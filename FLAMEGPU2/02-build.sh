#!/bin/bash

set -ETeuo pipefail

cmake \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_CUDA_COMPILER="${CUDA_PATH}/bin/nvcc" \
    -DCMAKE_CUDA_ARCHITECTURES="${SCALE_FAKE_CUDA_ARCH}" \
    -DCMAKE_PREFIX_PATH="${CUDA_PATH}" \
    -DFLAMEGPU_BUILD_TESTS=ON \
    -B"build" \
    "FLAMEGPU2"

make -C "build" -j"$(nproc)"
