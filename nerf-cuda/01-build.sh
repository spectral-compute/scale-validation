#!/bin/bash

set -e


# Configure.
cmake \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_CUDA_COMPILER="nvcc" \
    -DCMAKE_C_COMPILER="clang" \
    -DCMAKE_CXX_COMPILER="clang++" \
    -DCMAKE_CUDA_ARCHITECTURES="${CUDAARCHS}" \
    -B"build" \
    "nerf-cuda"

make -C build -j"$(nproc)"
