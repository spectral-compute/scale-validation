#!/bin/bash

set -e
SCRIPT_DIR="$(realpath "$(dirname "$0")")"
source "${SCRIPT_DIR}"/../util/args.sh "$@"

export PATH="${CUDA_DIR}/bin:${PATH}"
export CUDACXX="${CUDA_DIR}/bin/nvcc"
export LD_LIBRARY_PATH="${CUDA_DIR}/lib"

# Configure.
cmake \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_CUDA_ARCHITECTURES="$(echo "${GPU_ARCH}" | sed -E 's/sm_//g')" \
    -DCMAKE_CUDA_COMPILER="${CUDA_DIR}/bin/nvcc" \
    -DCMAKE_C_FLAGS="-Wno-error=implicit-function-declaration -Wno-error=implicit-int" \
    -DCMAKE_CXX_FLAGS="-Wno-unused-result -Wno-stringop-overread -Wno-switch" \
    -DCMAKE_CUDA_FLAGS="-Wno-unused-result -Wno-switch -Wno-error=implicit-const-int-float-conversion" \
    -B"${OUT_DIR}/GPUJPEG/build" \
    "${OUT_DIR}/GPUJPEG/GPUJPEG"

# Make sure we actually found CUDA.
"${SCRIPT_DIR}"/../util/check-cmake-cuda-version.sh "${OUT_DIR}/GPUJPEG/build"

# Build.
cmake --build "${OUT_DIR}/GPUJPEG/build" -j"${BUILD_JOBS}"