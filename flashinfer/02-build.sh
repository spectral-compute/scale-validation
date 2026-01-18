#!/bin/bash

set -ETeuo pipefail
SCRIPT_DIR="$(realpath "$(dirname "$0")")"
source "${SCRIPT_DIR}"/../util/args.sh "$@"

export SCALE_CUDA_VERSION="12.1"

# Configure.
cmake \
    -DCMAKE_BUILD_TYPE=Release \
    -Dflashinfer_NVCC_ARCHS="$(echo "${GPU_ARCH}" | sed -E 's/sm_//g')" \
    -DCMAKE_CUDA_ARCHITECTURES="$(echo "${GPU_ARCH}" | sed -E 's/sm_//g')" \
    -DCMAKE_CUDA_COMPILER="${CUDA_PATH}/bin/nvcc" \
    -DCMAKE_CUDA_FLAGS="-Wno-unused-result -Wno-deprecated-declarations" \
    -DCMAKE_CXX_COMPILER="${CUDA_PATH}/bin/clang++" \
    -DCMAKE_C_COMPILER="${CUDA_PATH}/bin/clang" \
    -DFLASHINFER_ENABLE_FP8=OFF \
    -DFLASHINFER_ENABLE_FP8_E4M3=OFF \
    -DFLASHINFER_ENABLE_FP8_E5M2=OFF \
    -DFLASHINFER_ENABLE_F16=ON \
    -DFLASHINFER_ENABLE_BF16=ON \
    -B"${OUT_DIR}/flashinfer/build" \
    "${OUT_DIR}/flashinfer/flashinfer"

# Build.
cmake --build "${OUT_DIR}/flashinfer/build" -j"$(nproc)"
