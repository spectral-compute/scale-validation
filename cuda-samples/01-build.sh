#!/bin/bash

set -ETeuo pipefail

# Configure.
cmake \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_CUDA_ARCHITECTURES="${CUDAARCHS}" \
    -DCMAKE_INSTALL_PREFIX="${OUT_DIR}/cuda-samples/install" \
    -B"build" \
    "cuda-samples"

make -C "build" -j"$(nproc)"
