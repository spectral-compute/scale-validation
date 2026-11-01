#!/usr/bin/env bash
# shellcheck source-path=SCRIPTDIR
. "$(dirname "$0")"/../../util/prelude.sh

# DEME's native HIP backend, for comparison.
cmake -B build -S DEM-Engine \
    -DCMAKE_BUILD_TYPE=Release \
    -DUSE_HIP=ON \
    -DCMAKE_HIP_ARCHITECTURES="${TEST_GPU_ARCH}" \
    -DCMAKE_PREFIX_PATH="${ROCM_PATH}" \
    -GNinja

ninja -C build
