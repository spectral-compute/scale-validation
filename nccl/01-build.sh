#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh

# Name the compiler: NCCL would take CUDA_HOME's, which in SCALE's NVIDIA mode is NVIDIA's nvcc.
# NCCL greps nvcc --version for "release", which also matches SCALE's install directory when its path has one.
CUDA_VERSION="$("${CUDACXX}" --version | sed -nEe 's/^Cuda compilation tools, release ([0-9.]+),.*$/\1/p')"
[[ -n "${CUDA_VERSION}" ]]
NCCL_ARGS=(CUDA_HOME="${CUDA_DIR}" NVCC="${CUDACXX}" CUDA_VERSION="${CUDA_VERSION}")
# NVIDIA GPUs: NCCL's and nccl-tests' own arch lists (every GPU the CUDA version supports), so one build runs on all of
# them. SCALE builds for one AMD GPU at a time; NCCL's fp8 multicast kernels (Blackwell only, bodies guarded by
# architecture) then get that one too.
TESTS_ARGS=()

if [[ "${SCALE_ENV:-}" == gfx* ]]; then
    GENCODE="-gencode=arch=compute_${CUDAARCHS},code=sm_${CUDAARCHS}"
    # SCALE for AMD's libcudart_static is the shared runtime, which can't replace the weak stubs NCCL adds for a static
    # one (enhcompat.cc): use NCCL's option for the shared runtime, which leaves them out.
    NCCL_ARGS+=(NVCC_GENCODE="${GENCODE}" NVCC_GENCODE_LDMC_FP8="${GENCODE}" CUDARTLIB=cudart)
    TESTS_ARGS+=(NVCC_GENCODE="${GENCODE}")

    # Large Simple-protocol sends get an extra warp, which spins on a different barrier from the workers. With warp32
    # emulated on a wave64 GPU, it shares a wave with 32 workers, and neither half can wait for the other: never use it.
    sed -Ee 's|^(#define NCCL_SIMPLE_EXTRA_GROUP_IF_NTHREADS_GE) \(3\*WARP_SIZE\)$|\1 (1 << 30)|' -i nccl/src/include/device.h
    grep -q '^#define NCCL_SIMPLE_EXTRA_GROUP_IF_NTHREADS_GE (1 << 30)$' nccl/src/include/device.h
    # The same goes for the tree's split of LL/LL128 threads between its reduce and broadcast: whole waves (64).
    sed -Ee 's|^( +nthreadsSplit = )\(nthreads\*7/\(10\*WARP_SIZE\)\)\*WARP_SIZE;$|\1(nthreads*7/(10*64))*64;|' \
        -i nccl/src/device/all_reduce.h
    grep -q '^ *nthreadsSplit = (nthreads\*7/(10\*64))\*64;$' nccl/src/device/all_reduce.h
    # And for send/recv's split of each work's warps: an even number of warps each (when there are enough).
    sed -Ee 's|^( +int nRecvWarpPerWork = )nWarpPerWork<=4 \? nWarpPerWork/2 : \(nWarpPerWork-1\)/2;$|\1nWarpPerWork<4 ? nWarpPerWork/2 : nWarpPerWork/4*2;|' \
        -e 's|^( +int nSendWarpPerWork = )nWarpPerWork<=4 \? nRecvWarpPerWork : nRecvWarpPerWork\+1;$|\1nRecvWarpPerWork;|' \
        -i nccl/src/device/sendrecv.h
    grep -q 'nWarpPerWork<4 ? nWarpPerWork/2 : nWarpPerWork/4\*2;$' nccl/src/device/sendrecv.h
    grep -q 'int nSendWarpPerWork = nRecvWarpPerWork;$' nccl/src/device/sendrecv.h
    # LL128 trusts a 128-byte line to arrive whole once its flag word has. SCALE reports xGMI links as NVLink, which
    # would turn it on by default, but AMD doesn't promise that over xGMI (RCCL leaves it off on gfx950). Leave it off
    # unless NCCL_PROTO asks for it.
    sed -Ee 's|^( +protoEnable\[f\*NCCL_NUM_PROTOCOLS\+p\] = p == NCCL_PROTO_LL128 \? )2( : 1;)$|\10\2|' \
        -i nccl/src/graph/tuning.cc
    grep -q 'protoEnable\[f\*NCCL_NUM_PROTOCOLS+p\] = p == NCCL_PROTO_LL128 ? 0 : 1;$' nccl/src/graph/tuning.cc

    # NCCL's device functions use its __shared__ state from many separately compiled files, which SCALE can't lay out
    # across files (the functions would trap). So compile all the device code as one file.
    DEVICE_OBJDIR="$(realpath -m nccl/build/obj/device)"
    mkdir -p "${DEVICE_OBJDIR}"
    # (The symmetric kernels don't use that state, so they stay as they are.)
    rm -rf "${DEVICE_OBJDIR}/gensrc"
    (cd nccl/src/device && ./generate.py "${DEVICE_OBJDIR}/gensrc" "")
    # The generated files each include the collective headers, which have no include guards: include them once. Each
    # also has its own runRing in an anonymous namespace, so give each a distinct name.
    UNITY=nccl/src/device/scale_unity.cu
    {
        echo '#include "common.cu"'
        echo '#include "onerank.cu"'
        sed -nEe 's/^#include "(.*)"$/\1/p' "${DEVICE_OBJDIR}"/gensrc/*.cu | sort -u | while read -r H; do
            echo "#define runRing runRing_${H%.h}"
            echo "#include \"${H}\""
            echo "#undef runRing"
        done
        cat "${DEVICE_OBJDIR}"/gensrc/*.cu | grep -v '^#include '
    } > "${UNITY}"
    NCCL_ARGS+=(LIB_OBJS="${DEVICE_OBJDIR}/scale_unity.cu.o ${DEVICE_OBJDIR}/genobj/host_table.cc.o \$(LIB_OBJS_SYM_GEN)")
fi

make -C nccl -j"$(nproc)" src.build "${NCCL_ARGS[@]}"

# nccl-tests reads a size suffix with "%1s" into a single char, so sscanf's NUL overwrites a neighbouring stack byte
# (with SCALE, main's saved argv). Give it room for the NUL.
sed -Ee 's/^    char size_lit;$/    char size_lit[2];/' -e 's/&size, &size_lit\)/\&size, size_lit)/' \
    -e 's/switch \(size_lit\) \{/switch (size_lit[0]) {/' -i nccl-tests/src/common.cu
grep -q 'char size_lit\[2\];' nccl-tests/src/common.cu
! grep -q '&size_lit' nccl-tests/src/common.cu || exit 1

# MPI=0: one process drives every GPU (-g N), which is enough for a single node.
make -C nccl-tests -j"$(nproc)" MPI=0 CUDA_HOME="${CUDA_DIR}" NVCC="${CUDACXX}" CUDA_VERSION="${CUDA_VERSION}" NCCL_HOME="$(realpath nccl/build)" \
    "${TESTS_ARGS[@]}"
