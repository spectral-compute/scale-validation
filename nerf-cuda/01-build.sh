#!/bin/bash

set -e
SCRIPT_DIR="$(realpath "$(dirname "$0")")"
source "${SCRIPT_DIR}"/../util/args.sh "$@"

mkdir -p "${OUT_DIR}/nerf-cuda/nerf-cuda/build"
cd "${OUT_DIR}/nerf-cuda/nerf-cuda/build"

# Configure.
cmake \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_CUDA_COMPILER="${CUDA_PATH}/bin/nvcc" \
    -DCMAKE_C_COMPILER="${CUDA_PATH}/bin/clang" \
    -DCMAKE_CXX_COMPILER="${CUDA_PATH}/bin/clang++" \
    -DCMAKE_CUDA_ARCHITECTURES="$(echo "${GPU_ARCH}" | sed -E 's/sm_//g')" \
    ..

# Build.
if [ "${VERBOSE}" == "1" ] ; then
    VERBOSE="VERBOSE=1"
else
    VERBOSE=
fi

make -j"${BUILD_JOBS}" ${VERBOSE}
