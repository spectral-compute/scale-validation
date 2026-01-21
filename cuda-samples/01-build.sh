#!/bin/bash

set -ETeuo pipefail

echo $NVCC_PREPEND_FLAGS
echo $NVCC_APPEND_FLAGS

# Configure.
cmake \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_CUDA_ARCHITECTURES="$(echo "${GPU_ARCH}" | sed -E 's/sm_//g')" \
    -DCMAKE_INSTALL_PREFIX="${OUT_DIR}/cuda-samples/install" \
    -B"build" \
    "cuda-samples"

make -C "build" -j"$(nproc)"
