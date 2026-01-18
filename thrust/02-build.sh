#!/bin/bash

set -ETeuo pipefail
SCRIPT_DIR="$(realpath "$(dirname "$0")")"
source "${SCRIPT_DIR}"/../util/args.sh "$@"

# Configure.
cmake \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_CUDA_COMPILER="${CUDA_PATH}/bin/nvcc" \
    -DTHRUST_DISABLE_ARCH_BY_DEFAULT=On \
    -DTHRUST_ENABLE_COMPUTE_"$(echo "${GPU_ARCH}" | sed -E 's/sm_//g')"=On \
    -DCMAKE_INSTALL_PREFIX="${OUT_DIR}/thrust/install" \
    -B"${OUT_DIR}/thrust/build" \
    "${OUT_DIR}/thrust/thrust"

# Make sure we actually found CUDA.
"${SCRIPT_DIR}"/../util/check-cmake-cuda-version.sh "${OUT_DIR}/thrust/build"

# Build.
cmake --build "${OUT_DIR}/thrust/build" -j"$(nproc)"
