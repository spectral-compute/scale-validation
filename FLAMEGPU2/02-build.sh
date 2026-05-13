#!/bin/bash

set -ETeuo pipefail

cmake \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_CUDA_COMPILER="nvcc" \
    -DCMAKE_CUDA_ARCHITECTURES="${CUDAARCHS}" \
    -DFLAMEGPU_BUILD_TESTS=ON \
    -B"build" \
    "FLAMEGPU2"

make -O -C "build" -j"$(nproc)"
