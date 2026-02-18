#!/bin/bash

set -ETeuo pipefail

# Configure.
cmake \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_C_COMPILER="clang" \
    -DCMAKE_CXX_COMPILER="clang++" \
    -DUSE_GPU=ON \
    -DUSE_CUDA=ON \
    -DBUILD_CPP_TEST=ON \
    -DCMAKE_CUDA_ARCHITECTURES="${CUDAARCHS}" \
    -DCMAKE_INSTALL_PREFIX="install" \
    -B"build" \
    "lightgbm"

make -C "build" install -j"$(nproc)"
