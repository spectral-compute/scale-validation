#!/bin/bash

set -ETeuo pipefail

export SCALE_CUDA_VERSION="12.1"

# Configure.
cmake \
    -DCMAKE_BUILD_TYPE=Release \
    -Dflashinfer_NVCC_ARCHS="${CUDAARCHS}" \
    -DCMAKE_CUDA_ARCHITECTURES="${CUDAARCHS}" \
    -DCMAKE_CUDA_COMPILER="nvcc" \
    -DCMAKE_CUDA_FLAGS="-Wno-unused-result -Wno-deprecated-declarations" \
    -DCMAKE_CXX_COMPILER="clang++" \
    -DCMAKE_C_COMPILER="clang" \
    -DFLASHINFER_ENABLE_FP8=OFF \
    -DFLASHINFER_ENABLE_FP8_E4M3=OFF \
    -DFLASHINFER_ENABLE_FP8_E5M2=OFF \
    -DFLASHINFER_ENABLE_F16=ON \
    -DFLASHINFER_ENABLE_BF16=ON \
    -B"build" \
    "flashinfer"

# Build.
cmake --build "build" -j"$(nproc)"
