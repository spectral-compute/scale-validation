#!/usr/bin/env bash
# shellcheck source-path=SCRIPTDIR
. "$(dirname "$0")"/../../util/prelude.sh

cd HeCBench

# Our own preset name, so it can't collide with the upstream hip-* presets (which
# only exist for a few archs, and build unoptimised). Built like 01-build.sh.
PRESET="scale-hip-$TEST_GPU_ARCH"

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
            "CMAKE_HIP_FLAGS_RELEASE": "-O3",
            "HECBENCH_ENABLE_CUDA": "OFF",
            "HECBENCH_ENABLE_HIP": "ON",
            "HECBENCH_ENABLE_SYCL": "OFF",
            "HECBENCH_ENABLE_OPENMP": "OFF",
            "HECBENCH_HIP_ARCH": "${TEST_GPU_ARCH}",
            "CMAKE_CXX_COMPILER": "hipcc"
        }
    }]
}
JSON

# Comment out benchmarks known to fail to compile.
disable() {
    for b in "$@"; do
        sed -i -E "s/^([[:space:]]*)(${b})[[:space:]]*\$/\1#\2  # HIP: known failure/" src/CMakeLists.txt
    done
}

# The gfx major version is everything but the last two (hex) digits, e.g. 9
# for gfx90a, 11 for gfx1100.
if [[ "$TEST_GPU_ARCH" =~ ^gfx([0-9]+)[0-9a-f]{2}$ && ${BASH_REMATCH[1]} -ge 10 ]]; then
    # awbarrier: its inline asm uses buffer_load ... lds, which gfx10 and
    # newer (RDNA) dropped.
    disable awbarrier
fi

python3 tools/hecbench --verbose build --preset "$PRESET"
