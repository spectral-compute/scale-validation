#!/bin/bash

set -ETeuo pipefail

# Configure.
cmake \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_CUDA_COMPILER="nvcc" \
    -DCMAKE_CUDA_ARCHITECTURES="${CUDAARCHS}" \
    -DGGML_CUDA=ON \
    -DGGML_NATIVE=OFF \
    -DLLAMA_BUILD_UI=OFF \
    -DCMAKE_INSTALL_PREFIX="install" \
    -B"build" \
    "llama.cpp"

make -O -C "build" install -j"$(nproc)"
