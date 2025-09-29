#!/bin/bash

set -ETeuo pipefail
SCRIPT_DIR="$(realpath "$(dirname "$0")")"
source "${SCRIPT_DIR}"/../util/args.sh "$@"

export SCALE_CUDA_VERSION="11.4"
# Configure.
cmake \
    -DCMAKE_BUILD_TYPE=RelWithDebInfo \
    -B"${OUT_DIR}/tiny-cuda-nn/build" \
    "${OUT_DIR}/tiny-cuda-nn/tiny-cuda-nn"

# Make sure we actually found CUDA.
"${SCRIPT_DIR}"/../util/check-cmake-cuda-version.sh "${OUT_DIR}/tiny-cuda-nn/build"

# Build.
cmake --build "${OUT_DIR}/tiny-cuda-nn/build" -j"${BUILD_JOBS}"
