#!/bin/bash

set -e

# Configure.
cmake \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_CUDA_COMPILER="nvcc" \
    -DCUDA_TOOLKIT_ROOT_DIR="${CUDA_PATH}" \
    -DAF_BUILD_OPENCL=OFF \
    -DAF_BUILD_CUDA=ON \
    -DAF_BUILD_DOCS=OFF \
    -DAF_BUILD_ONEAPI=OFF \
    -DAF_WITH_CUDNN=OFF \
    -DAF_WITH_NONFREE=ON \
    -DAF_WITH_FMT_HEADER_ONLY=ON \
    -B"build" \
    "arrayfire"

make -C "build" -j"$(nproc)"
