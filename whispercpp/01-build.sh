#!/bin/bash

set -e

# Configure.
cmake \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_CUDA_COMPILER="${CUDA_PATH}/bin/nvcc" \
    -DCMAKE_CUDA_ARCHITECTURES="${SCALE_FAKE_CUDA_ARCH}" \
    -DGGML_CCACHE=OFF \
    -DGGML_CUDA=ON \
    -DGGML_CUDA_NO_PEER_COPY=ON \
    -B"build" \
    "whispercpp"

make -C "build" -j"$(nproc)"
