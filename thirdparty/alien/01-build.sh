#!/bin/bash

set -ETeuo pipefail
SCRIPT_DIR="$(realpath "$(dirname "$0")")"
source "${SCRIPT_DIR}"/../util/args.sh "$@"

export PATH="${CUDA_DIR}/bin:${PATH}"
export CUDACXX="${CUDA_DIR}/bin/nvcc"

# Configure.
cmake \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_CUDA_ARCHITECTURES="$(echo "${GPU_ARCH}" | sed -E 's/sm_//g')" \
    -DCMAKE_CUDA_COMPILER="${CUDA_DIR}/bin/nvcc" \
    -DCMAKE_CXX_FLAGS="-Wno-unused-result -Wno-stringop-overread -Wno-format-truncation -Wno-switch" \
    -DCMAKE_CUDA_FLAGS="-Wno-unused-result -Wno-switch -Wno-error=implicit-const-int-float-conversion" \
    -B"${OUT_DIR}/alien/build" \
    "${OUT_DIR}/alien/alien"

# Make sure we actually found CUDA.
"${SCRIPT_DIR}"/../util/check-cmake-cuda-version.sh "${OUT_DIR}/alien/build"

# Build.
cmake --build "${OUT_DIR}/alien/build" -j"${BUILD_JOBS}"
