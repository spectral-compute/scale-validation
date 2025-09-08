#!/bin/bash

set -ETeuo pipefail
SCRIPT_DIR="$(realpath "$(dirname "$0")")"
source "${SCRIPT_DIR}"/../util/args.sh "$@"

export SCALE_CUDA_VERSION="12.1"

# Configure.
cmake \
    -DCMAKE_BUILD_TYPE=Release \
    -DCUTLASS_NVCC_ARCHS="$(echo "${GPU_ARCH}" | sed -E 's/sm_//g')" \
    -DCUTLASS_TEST_UNIT_ENABLE_WARNINGS=ON \
    -DCMAKE_CUDA_ARCHITECTURES="$(echo "${GPU_ARCH}" | sed -E 's/sm_//g')" \
    -DCMAKE_CUDA_COMPILER="${CUDA_PATH}/bin/nvcc" \
    -DCMAKE_CUDA_FLAGS="-Wno-unused-result -Wno-deprecated-declarations" \
    -DCMAKE_CXX_COMPILER="${CUDA_PATH}/bin/clang++" \
    -DCMAKE_C_COMPILER="${CUDA_PATH}/bin/clang" \
    -B"${OUT_DIR}/cutlass/build" \
    "${OUT_DIR}/cutlass/cutlass"

# Make sure we actually found CUDA.
"${SCRIPT_DIR}"/../util/check-cmake-cuda-version.sh "${OUT_DIR}/cutlass/build"

# Build.
cmake --build "${OUT_DIR}/cutlass/build" -j"${BUILD_JOBS}"
