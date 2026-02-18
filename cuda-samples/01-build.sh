#!/bin/bash

set -ETeuo pipefail

echo $NVCC_PREPEND_FLAGS
echo $NVCC_APPEND_FLAGS

# Configure.
cmake \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_CUDA_ARCHITECTURES="${CUDAARCHS}" \
    -DCMAKE_INSTALL_PREFIX="${OUT_DIR}/cuda-samples/install" \
    -B"build" \
    "cuda-samples"

make -C "build" -j"$(nproc)"
