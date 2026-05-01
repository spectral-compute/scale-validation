#!/bin/bash

set -ETeuo pipefail

# Configure.
cmake \
    -DCMAKE_BUILD_TYPE=Release \
    -DQUDA_TARGET_TYPE="CUDA" \
    -DCMAKE_CUDA_ARCHITECTURES="${CUDAARCHS}" \
    -DQUDA_GPU_ARCH="${CUDAARCHS}" \
    -DCMAKE_INSTALL_PREFIX="install" \
    -B"build" \
    "quda"

make -O -C "build" install -j"$(nproc)"
