#!/bin/bash

set -ETeuo pipefail
SCRIPT_DIR="$(realpath "$(dirname "$0")")"
source "${SCRIPT_DIR}"/../util/args.sh "$@"

echo $NVCC_PREPEND_FLAGS
echo $NVCC_APPEND_FLAGS

# Configure.
cmake \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_CUDA_ARCHITECTURES="$(echo "${GPU_ARCH}" | sed -E 's/sm_//g')" \
    -DCMAKE_INSTALL_PREFIX="${OUT_DIR}/cuda-samples/install" \
    -B"${OUT_DIR}/cuda-samples/build" \
    "${OUT_DIR}/cuda-samples/cuda-samples"

make -C "${OUT_DIR}/cuda-samples/build" -j"${BUILD_JOBS}"
