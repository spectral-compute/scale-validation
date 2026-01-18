#!/bin/bash

set -ETeuo pipefail
SCRIPT_DIR="$(realpath "$(dirname "$0")")"
source "${SCRIPT_DIR}"/../util/args.sh "$@"

cmake \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX="${OUT_DIR}/CV-CUDA/install" \
    -DCMAKE_CUDA_ARCHITECTURES="$(echo "${GPU_ARCH}" | sed -E 's/sm_//g')" \
    -DCMAKE_CUDA_COMPILER="${CUDA_PATH}/bin/nvcc" \
    -DBUILD_TESTS=ON \
    -B"${OUT_DIR}/CV-CUDA/build" \
    "${OUT_DIR}/CV-CUDA/CV-CUDA"

cmake --build "${OUT_DIR}/CV-CUDA/build" -j"$(nproc)"
