#!/bin/bash

set -ETeuo pipefail

# Configure.
cmake \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_CUDA_COMPILER="nvcc" \
    -DCMAKE_CUDA_ARCHITECTURES="${CUDAARCHS}" \
    -DLLAMA_CUBLAS=ON \
    -DCMAKE_INSTALL_PREFIX="install" \
    -B"build" \
    "llama.cpp"

make -C "build" install -j"$(nproc)"
