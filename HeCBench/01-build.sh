#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh

cd HeCBench

# Our own preset name, so it can't collide with the upstream cuda-sm<N> presets.
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

# test.sh doesn't export its mode; SCALE_ENV is set by scaleenv.
if [[ -n "${SCALE_ENV:-}" ]]; then
    disable prefetch

    case "$TEST_GPU_ARCH" in
    gfx1201) disable blas-fp8gemm attentionMultiHeadKVCache mlp ;;
    gfx90a | gfx942) disable mlp ;;
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
