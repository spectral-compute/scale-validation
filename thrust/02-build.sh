#!/bin/bash

set -ETeuo pipefail

# Configure.
cmake \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_CUDA_COMPILER="${CUDA_PATH}/bin/nvcc" \
    -DTHRUST_DISABLE_ARCH_BY_DEFAULT=On \
    -DTHRUST_ENABLE_COMPUTE_"${SCALE_FAKE_CUDA_ARCH}"=On \
    -DCMAKE_INSTALL_PREFIX="install" \
    -B"build" \
    "thrust"

# Build.
cmake --build "build" -j"$(nproc)"
