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

# test.sh doesn't export its mode; SCALE_ENV is set by scaleenv.
if [[ -n "${SCALE_ENV:-}" && "$TEST_GPU_ARCH" == sm_120 ]]; then
    # qkv, permute: link error on isfinite. d3q19-bgk: nvlink can't resolve a
    # static __constant__ variable. sobol: ptxas exceeds the constant data
    # limit. quant3MatMul: ambiguous half2 operator=.
    disable qkv permute d3q19-bgk sobol quant3MatMul
fi
if [[ -n "${SCALE_ENV:-}" && "$TEST_GPU_ARCH" == gfx11* ]]; then
    # assert: on gfx11, LLVM's trap raises a queue exception, which aborts the
    # process rather than returning cudaErrorAssert.
    disable assert
fi

export CUDAFLAGS="-Wno-cuda-implicit-real-arch -Wno-unused-command-line-argument -Wno-write-strings"
python3 tools/hecbench --verbose build --preset "$PRESET"
