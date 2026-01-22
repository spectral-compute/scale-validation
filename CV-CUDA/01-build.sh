#!/bin/bash

set -ETeuo pipefail

cmake \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX="install" \
    -DCMAKE_CUDA_ARCHITECTURES="${SCALE_FAKE_CUDA_ARCH}" \
    -DCMAKE_CUDA_COMPILER="${CUDA_PATH}/bin/nvcc" \
    -DBUILD_TESTS=ON \
    -B"build" \
    "CV-CUDA"

make -C "build" -j"$(nproc)"
