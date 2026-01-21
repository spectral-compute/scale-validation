#!/bin/bash

set -e

# Configure.
cmake \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_C_COMPILER="${CUDA_PATH}/bin/clang" \
    -DCMAKE_CXX_COMPILER="${CUDA_PATH}/bin/clang++" \
    -DCMAKE_CXX_FLAGS="-Wno-error=c++11-narrowing" \
    -DFLIP_ENABLE_CUDA=ON \
    -B"build" \
    "nvflip/src"

make -C "build" -j"$(nproc)"
