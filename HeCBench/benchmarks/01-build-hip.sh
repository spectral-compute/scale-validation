#!/usr/bin/env bash
# shellcheck source-path=SCRIPTDIR
. "$(dirname "$0")"/../../util/prelude.sh

cd HeCBench

PRESET="hip-$TEST_GPU_ARCH"

# Upstream only ships hip-* presets for a handful of archs; add a user preset
# mirroring theirs for any other.
if ! cmake --list-presets=configure | grep -qF "\"${PRESET}\""; then
    log "No upstream preset ${PRESET}, creating one in CMakeUserPresets.json"
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
            "CMAKE_CXX_COMPILER": "hipcc"
        }
    }]
}
JSON
fi

python3 tools/hecbench --verbose build --preset "$PRESET"
