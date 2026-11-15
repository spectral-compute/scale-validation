#!/usr/bin/env bash
# shellcheck source-path=SCRIPTDIR
. "$(dirname "$0")"/../../util/prelude.sh

cd HeCBench

# Our own preset, built like 01-build.sh's (-O3, asserts kept). Upstream's
# hip-* presets only exist for a few archs (gfx908, gfx90a, gfx942, gfx1012,
# gfx1030) and build unoptimised, which would skew the comparison with SCALE.
PRESET="scale-hip-$TEST_GPU_ARCH"

cat >CMakeUserPresets.json <<JSON
{
    "version": 3,
    "configurePresets": [{
        "name": "${PRESET}",
        "inherits": "default",
        "cacheVariables": {
            "HECBENCH_ENABLE_CUDA": "OFF",
            "HECBENCH_ENABLE_HIP": "ON",
            "HECBENCH_ENABLE_SYCL": "OFF",
            "HECBENCH_ENABLE_OPENMP": "OFF",
            "HECBENCH_HIP_ARCH": "${TEST_GPU_ARCH}",
            "CMAKE_CXX_COMPILER": "hipcc",
            "CMAKE_BUILD_TYPE": "Release",
            "CMAKE_C_FLAGS_RELEASE": "-O3",
            "CMAKE_CXX_FLAGS_RELEASE": "-O3",
            "CMAKE_HIP_FLAGS_RELEASE": "-O3"
        }
    }]
}
JSON

# Optional: a space-separated subset of benchmark names, without the model
# suffix (default: all).
read -ra BENCHES <<<"${HECBENCH_BENCHMARKS:-}"
BENCHES=("${BENCHES[@]/%/-hip}")
python3 tools/hecbench --verbose build --preset "$PRESET" "${BENCHES[@]}"
