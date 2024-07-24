#!/bin/bash

set -ETeuo pipefail
SCRIPT_DIR="$(realpath "$(dirname "$0")")"
source "${SCRIPT_DIR}"/../util/args.sh "$@"

export PATH="${CUDA_DIR}/bin:${PATH}"
export CUDACXX="${CUDA_DIR}/bin/nvcc"

# Configure.
cmake \
    -DCMAKE_BUILD_TYPE=Release \
    -DCUTLASS_NVCC_ARCHS="$(echo "${GPU_ARCH}" | sed -E 's/sm_//g')" \
    -DCMAKE_CUDA_ARCHITECTURES="$(echo "${GPU_ARCH}" | sed -E 's/sm_//g')" \
    -DCMAKE_CUDA_COMPILER="${CUDA_DIR}/bin/nvcc" \
    -DCMAKE_CXX_COMPILER="${CUDA_DIR}/bin/clang++" \
    -DCMAKE_C_COMPILER="${CUDA_DIR}/bin/clang" \
    -DCMAKE_CXX_FLAGS="-Wno-unused-result -Wno-sign-conversion -Wno-shorten-64-to-32 -ferror-limit=999" \
    -DCMAKE_CUDA_FLAGS="-Wno-unused-result -Wno-sign-conversion -Wno-shorten-64-to-32 -ferror-limit=999" \
    -B"${OUT_DIR}/cutlass/build" \
    "${OUT_DIR}/cutlass/cutlass"

# Make sure we actually found CUDA.
"${SCRIPT_DIR}"/../util/check-cmake-cuda-version.sh "${OUT_DIR}/cutlass/build"

# Build.
cmake --build "${OUT_DIR}/cutlass/build" -j"${BUILD_JOBS}"
