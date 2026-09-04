#!/bin/bash

set -ETeuo pipefail

# Configure.
cmake \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_CUDA_ARCHITECTURES="${CUDAARCHS}" \
    -DCMAKE_INSTALL_PREFIX="install" \
    -B"build" \
    "cuda-samples"

make -O -C "build" -j"$(nproc)"
