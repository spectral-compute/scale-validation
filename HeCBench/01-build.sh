#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh

cd HeCBench

# Our own preset name, so it can't collide with the upstream cuda-sm<N> presets.
# Like HeCBench's Makefiles, build with -O3 but keep asserts: some benchmarks
# verify their results with them. Upstream's presets build unoptimised.
PRESET="scale-cuda-sm${CUDAARCHS#sm_}"

cat >CMakeUserPresets.json <<JSON
{
    "version": 3,
    "configurePresets": [{
        "name": "${PRESET}",
        "inherits": "default",
        "cacheVariables": {
            "CMAKE_BUILD_TYPE": "Release",
            "CMAKE_C_FLAGS_RELEASE": "-O3",
            "CMAKE_CXX_FLAGS_RELEASE": "-O3",
            "CMAKE_CUDA_FLAGS_RELEASE": "-O3",
            "CMAKE_CUDA_COMPILER": "nvcc",
            "HECBENCH_ENABLE_CUDA": "ON",
            "HECBENCH_ENABLE_HIP": "OFF",
            "HECBENCH_ENABLE_SYCL": "OFF",
            "HECBENCH_ENABLE_OPENMP": "OFF",
            "HECBENCH_CUDA_ARCH": "${CUDAARCHS#sm_}"
        }
    }]
}
JSON

# Comment out benchmarks known to fail to compile. These will steadily be addressed.
disable() {
    for b in "$@"; do
        sed -i -E "s/^([[:space:]]*)(${b})[[:space:]]*\$/\1#\2  # SCALE: known failure/" src/CMakeLists.txt
    done
}

# tgvnn: upstream tgvnn-cuda/CMakeLists.txt lists a nonexistent src/tgv.cu,
# which fails configuration for any CUDA toolchain.
disable tgvnn

# test.sh doesn't export its mode; SCALE_ENV is set by scaleenv.
if [[ -n "${SCALE_ENV:-}" ]]; then
    # mlp: SCALE's cublasLt.h only forward-declares the cublasLt*Opaque_t structs.
    disable prefetch mlp
    # f16sp: SCALE lacks cublasDotEx_64. trimul: SCALE lacks the
    # __pipeline_* primitives (cuda_pipeline_primitives.h).
    disable f16sp trimul
    # blas-groupgemm, megablocks: SCALE lacks cublasGemmGroupedBatchedEx.
    # swiglu-oai: SCALE has no host definition of __nv_cvt_float2_to_fp4x2.
    disable blas-groupgemm megablocks swiglu-oai

    case "$TEST_GPU_ARCH" in
    gfx1201) disable blas-fp8gemm attentionMultiHeadKVCache ;;
    sm_120)
        disable qkv d3q19-bgk quant3MatMul sobol
        # "error: use of undeclared identifier '__NV_ATOMIC_RELAXED'"
        disable michalewicz 'graphB\+' scatter hausdorff lebesgue atomicCAS
        # Link error on isfinite
        disable permute
        ;;
    esac
fi

export CUDAFLAGS="-Wno-cuda-implicit-real-arch -Wno-unused-command-line-argument -Wno-write-strings"
python3 tools/hecbench --verbose build --preset "$PRESET"
