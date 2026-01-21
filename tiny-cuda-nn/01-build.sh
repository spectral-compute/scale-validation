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

# Build.
cmake --build "${OUT_DIR}/tiny-cuda-nn/build" -j"$(nproc)"
