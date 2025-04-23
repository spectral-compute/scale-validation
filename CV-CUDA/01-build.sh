#!/bin/bash

set -ETeuo pipefail
SCRIPT_DIR="$(realpath "$(dirname "$0")")"
source "${SCRIPT_DIR}"/../util/args.sh "$@"

${OUT_DIR}/CV-CUDA/CV-CUDA/init_repo.sh

cmake \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_CUDA_ARCHITECTURES="$(echo "${GPU_ARCH}" | sed -E 's/sm_//g')" \
    -DCMAKE_C_COMPILER="/usr/bin/gcc-12" \
    -DCMAKE_CXX_COMPILER="/usr/bin/g++-12" \
    -DCMAKE_CUDA_COMPILER="${CUDA_PATH}/bin/nvcc" \
    -DBUILD_TESTS=ON \
    -B"${OUT_DIR}/CV-CUDA/build" \
    "${OUT_DIR}/CV-CUDA/CV-CUDA"

# Make sure we actually found CUDA.
"${SCRIPT_DIR}"/../util/check-cmake-cuda-version.sh "${OUT_DIR}/CV-CUDA/build"

cmake --build "${OUT_DIR}/CV-CUDA/build" -j"${BUILD_JOBS}"
