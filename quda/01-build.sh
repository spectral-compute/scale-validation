#!/bin/bash

set -ETeuo pipefail

# Configure.
cmake \
    -DCMAKE_BUILD_TYPE=Release \
    -DQUDA_TARGET_TYPE="CUDA" \
    -DCMAKE_CUDA_ARCHITECTURES="${SCALE_FAKE_CUDA_ARCH}" \
    -DQUDA_GPU_ARCH="${SCALE_FAKE_CUDA_ARCH}" \
    -DCMAKE_INSTALL_PREFIX="install" \
    -B"build" \
    "quda"

make -C "build" install -j"$(nproc)"
