#!/bin/bash

set -ETeuo pipefail

export SCALE_CUDA_VERSION="11.8"
# Configure.
cmake \
    -DCMAKE_BUILD_TYPE=Release \
    -DCUTLASS_NVCC_ARCHS="${CUDAARCHS}" \
    -DCUTLASS_TEST_UNIT_ENABLE_WARNINGS=ON \
    -DCMAKE_CUDA_ARCHITECTURES="${CUDAARCHS}" \
    -DCMAKE_CUDA_COMPILER="nvcc" \
    -DCMAKE_CUDA_FLAGS="-Wno-unused-result -Wno-deprecated-declarations" \
    -DCMAKE_CXX_COMPILER="clang++" \
    -DCMAKE_C_COMPILER="clang" \
    -B"build" \
    "cutlass"

# Build.
make -C "build" -j"$(nproc)"
