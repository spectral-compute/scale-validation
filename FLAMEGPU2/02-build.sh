#!/bin/bash

set -ETeuo pipefail

cmake \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_CUDA_COMPILER="nvcc" \
    -DCMAKE_CUDA_ARCHITECTURES="${CUDAARCHS}" \
    -DCMAKE_PREFIX_PATH="${CUDA_PATH}" \
    -DFLAMEGPU_BUILD_TESTS=ON \
    -B"build" \
    "FLAMEGPU2"

make -C "build" -j"$(nproc)"
