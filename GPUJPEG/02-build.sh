#!/bin/bash

set -e

# Configure.
cmake \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_CUDA_ARCHITECTURES="${SCALE_FAKE_CUDA_ARCH}" \
    -DCMAKE_CUDA_COMPILER="${CUDA_PATH}/bin/nvcc" \
    -DCMAKE_C_FLAGS="-Wno-error=implicit-function-declaration -Wno-error=implicit-int" \
    -DCMAKE_CXX_FLAGS="-Wno-stringop-overread" \
    -DCMAKE_CUDA_FLAGS="-Wno-error=implicit-const-int-float-conversion" \
    -B"build" \
    "GPUJPEG"

# Build.
cmake --build "build" -j"$(nproc)"
