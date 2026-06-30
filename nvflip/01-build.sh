#!/bin/bash

set -e

# Configure.
cmake \
    -DCMAKE_BUILD_TYPE=Release \
    -DFLIP_ENABLE_CUDA=ON \
    -DCMAKE_CUDA_FLAGS="-arch=sm_$CUDAARCHS" \
    -B"build" \
    "nvflip/src"

make -O -C "build" -j"$(nproc)"
