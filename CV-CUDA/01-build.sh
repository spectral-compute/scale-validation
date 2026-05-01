#!/bin/bash

set -ETeuo pipefail

cmake \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX="install" \
    -DCMAKE_CUDA_ARCHITECTURES="${CUDAARCHS}" \
    -DCMAKE_CUDA_COMPILER="nvcc" \
    -DBUILD_TESTS=ON \
    -B"build" \
    "CV-CUDA"

make -O -C "build" -j"$(nproc)"
