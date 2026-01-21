#!/bin/bash

set -ETeuo pipefail

export SCALE_CUDA_VERSION="11.8"
# Configure.
cmake \
    -DCMAKE_BUILD_TYPE=Release \
    -DCUTLASS_NVCC_ARCHS="${SCALE_FAKE_CUDA_ARCH}" \
    -DCUTLASS_TEST_UNIT_ENABLE_WARNINGS=ON \
    -DCMAKE_CUDA_ARCHITECTURES="${SCALE_FAKE_CUDA_ARCH}" \
    -DCMAKE_CUDA_COMPILER="${CUDA_PATH}/bin/nvcc" \
    -DCMAKE_CUDA_FLAGS="-Wno-unused-result -Wno-deprecated-declarations" \
    -DCMAKE_CXX_COMPILER="${CUDA_PATH}/bin/clang++" \
    -DCMAKE_C_COMPILER="${CUDA_PATH}/bin/clang" \
    -B"build" \
    "cutlass"

# Build.
make -C "build" -j"$(nproc)"
