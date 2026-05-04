#!/bin/bash

set -ETeuo pipefail

# Configure.
cmake \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_CUDA_ARCHITECTURES="${CUDAARCHS}" \
    -DCMAKE_CUDA_COMPILER="nvcc" \
    -DCMAKE_CUDA_FLAGS="-Wno-unused-result -Wno-deprecated-declarations" \
    -B"build" \
    "cudahandbook"

# Build.
make -C "build" -j"$(nproc)"

