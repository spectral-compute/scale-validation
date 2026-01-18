#!/bin/bash

set -ETeuo pipefail
SCRIPT_DIR="$(realpath "$(dirname "$0")")"
source "${SCRIPT_DIR}"/../util/args.sh "$@"

# Configure.
cmake \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_CXX_FLAGS="-Wno-stringop-overread -Wno-format-truncation" \
    -DCMAKE_CUDA_ARCHITECTURES="$(echo "${GPU_ARCH}" | sed -E 's/sm_//g')" \
    -DCMAKE_CUDA_COMPILER="${CUDA_PATH}/bin/nvcc" \
    -B"${OUT_DIR}/alien/build" \
    "${OUT_DIR}/alien/alien"

# Make sure we actually found CUDA.
"${SCRIPT_DIR}"/../util/check-cmake-cuda-version.sh "${OUT_DIR}/alien/build"

# Build.
cmake --build "${OUT_DIR}/alien/build" -j"$(nproc)"
