#!/bin/bash

set -e

GGML_NATIVE=On
if [ "${NO_TUNE_NATIVE:-0}" == "1" ]; then
    GGML_NATIVE=Off
fi

# Configure.
cmake \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_CUDA_COMPILER="nvcc" \
    -DCMAKE_CUDA_ARCHITECTURES="${CUDAARCHS}" \
    -DGGML_CCACHE=OFF \
    -DGGML_CUDA=ON \
    -DGGML_CUDA_NO_PEER_COPY=ON \
    -DGGML_NATIVE=$GGML_NATIVE \
    -B"build" \
    "whispercpp"

make -C "build" -j"$(nproc)"
