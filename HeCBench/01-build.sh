#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh

cd HeCBench

# Our own preset name, so it can't collide with the upstream cuda-sm<N> presets.
# Like HeCBench's Makefiles, build with -O3 but keep asserts (Release would add
# -DNDEBUG): some benchmarks verify their results with them. Upstream's presets
# set no build type, so build unoptimised.
PRESET="scale-cuda-sm${CUDAARCHS#sm_}"

cat >CMakeUserPresets.json <<JSON
{
    "version": 3,
    "configurePresets": [{
        "name": "${PRESET}",
        "inherits": "default",
        "cacheVariables": {
            "CMAKE_CUDA_COMPILER": "nvcc",
            "HECBENCH_ENABLE_CUDA": "ON",
            "HECBENCH_ENABLE_HIP": "OFF",
            "HECBENCH_ENABLE_SYCL": "OFF",
            "HECBENCH_ENABLE_OPENMP": "OFF",
            "HECBENCH_CUDA_ARCH": "${CUDAARCHS#sm_}",
            "CMAKE_BUILD_TYPE": "Release",
            "CMAKE_C_FLAGS_RELEASE": "-O3",
            "CMAKE_CXX_FLAGS_RELEASE": "-O3",
            "CMAKE_CUDA_FLAGS_RELEASE": "-O3"
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

# test.sh doesn't export its mode; SCALE_ENV is set by scaleenv.
if [[ -n "${SCALE_ENV:-}" ]]; then
    # mlp: SCALE's cublasLt.h only forward-declares the cublasLt*Opaque_t structs.
    # f16sp, tgvnn: SCALE lacks cuBLAS's 64-bit-integer (_64) API.
    # ssm2: no wmma::load_matrix_sync from float for tf32 fragments.
    # trimul: SCALE's cuda_pipeline.h lacks the __pipeline_* primitives.
    # twell: thread block clusters, wgmma and TMA (sm_90).
    disable prefetch mlp f16sp tgvnn ssm2 trimul twell

    case "$TEST_GPU_ARCH" in
    gfx1201) disable blas-fp8gemm attentionMultiHeadKVCache ;;
    sm_120)
        disable d3q19-bgk quant3MatMul sobol
        # "error: use of undeclared identifier '__NV_ATOMIC_RELAXED'"
        disable michalewicz 'graphB\+' scatter hausdorff lebesgue atomicCAS
        ;;
    esac
fi

export CUDAFLAGS="-Wno-cuda-implicit-real-arch -Wno-unused-command-line-argument -Wno-write-strings"
# Optional: a space-separated subset of benchmark names, without the model
# suffix (default: all).
read -ra BENCHES <<<"${HECBENCH_BENCHMARKS:-}"
BENCHES=("${BENCHES[@]/%/-cuda}")
python3 tools/hecbench --verbose build --preset "$PRESET" "${BENCHES[@]}"
