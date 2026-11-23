#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh

JOBS="$(nproc)"
GENCODE="-gencode=arch=compute_${CUDAARCHS},code=sm_${CUDAARCHS}"

# NCCL builds its fp8 multicast kernels for Blackwell only (sm_100f), and guards their bodies by architecture: build
# them for the target too. Name the compiler (NCCL's NVCC knob, which defaults to CUDA_HOME's): in SCALE's NVIDIA mode
# CUDA_HOME is NVIDIA's toolkit, which SCALE uses for headers and libraries, so its nvcc is NVIDIA's. CUDACXX names
# the compiler in every mode. Link the shared CUDA runtime, as the PyTorch that loads this NCCL does.
NCCL_ARGS=(CUDA_HOME="${CUDA_DIR}" NVCC="${CUDACXX}" NVCC_GENCODE="${GENCODE}" NVCC_GENCODE_LDMC_FP8="${GENCODE}"
    CUDARTLIB=cudart)

# NCCL changes proposed upstream (see each patch's message):
# - DOCA GPUNetIO skips its own CUDA driver types when cuda.h is included (SCALE's cuda_runtime.h includes it);
# - a COLL_UNROLL make option sets the collective unroll, and with it the dynamic shared memory per block.
# Already applied when the workdir is kept (test.sh --keep).
for P in "${SCRIPT_DIR}"/*.patch; do
    git -C nccl apply --reverse --check "${P}" 2>/dev/null || git -C nccl apply "${P}"
done

# SCALE on AMD GPUs (scaleenv's target is a gfx architecture).
if [[ "${SCALE_ENV:-}" == gfx* ]]; then
    # NCCL sizes its dynamic shared memory from the compute capability (8.9 on SCALE: 82240 B, for NVIDIA's 99 KB).
    # AMD GPUs other than gfx950 have 64 KB per workgroup, so every communicator init failed. Unroll 4 (sm_75's) needs
    # 41280 B.
    if [[ "${SCALE_ENV}" != gfx950 ]]; then
        NCCL_ARGS+=(COLL_UNROLL=4)
    fi

    # SCALE gap: rdc-shared-lds. NCCL's device functions use its __shared__ state from many separately compiled
    # files, which SCALE can't lay out across files (the functions would trap). So compile all the device code as one
    # file. (The symmetric kernels don't use that state, so they stay as they are.)
    DEVICE_OBJDIR="$(realpath -m nccl/build/obj/device)"
    mkdir -p "${DEVICE_OBJDIR}"
    rm -rf "${DEVICE_OBJDIR}/gensrc"
    (cd nccl/src/device && ./generate.py "${DEVICE_OBJDIR}/gensrc" "")
    # The generated files each include the collective headers, which have no include guards: include them once. Each
    # also has its own runRing in an anonymous namespace, so give each a distinct name.
    UNITY=nccl/src/device/scale_unity.cu
    {
        echo '#include "common.cu"'
        echo '#include "onerank.cu"'
        while read -r H; do
            echo "#define runRing runRing_${H%.h}"
            echo "#include \"${H}\""
            echo "#undef runRing"
        done < <(sed -nEe 's/^#include "(.*)"$/\1/p' "${DEVICE_OBJDIR}"/gensrc/*.cu | sort -u)
        cat "${DEVICE_OBJDIR}"/gensrc/*.cu | grep -v '^#include '
    } >"${UNITY}"
    NCCL_ARGS+=(LIB_OBJS="${DEVICE_OBJDIR}/scale_unity.cu.o ${DEVICE_OBJDIR}/genobj/host_table.cc.o \$(LIB_OBJS_SYM_GEN)")
fi

make -C nccl -j"${JOBS}" src.build "${NCCL_ARGS[@]}"

# MPI=0: one process drives every GPU (-g N), which is enough for a single node.
make -C nccl-tests -j"${JOBS}" MPI=0 CUDA_HOME="${CUDA_DIR}" NVCC="${CUDACXX}" NCCL_HOME="$(realpath nccl/build)" \
    NVCC_GENCODE="${GENCODE}"

# Counts the GPUs for 02-test.sh (there may be no nvidia-smi).
cat >gpu_count.cu <<'EOF'
#include <cstdio>
int main() {
    int n = 0;
    cudaError_t e = cudaGetDeviceCount(&n);
    if (e != cudaSuccess) {
        fprintf(stderr, "cudaGetDeviceCount: %s\n", cudaGetErrorString(e));
        return 1;
    }
    printf("%d\n", n);
    return 0;
}
EOF
"${CUDACXX}" -o gpu_count gpu_count.cu
