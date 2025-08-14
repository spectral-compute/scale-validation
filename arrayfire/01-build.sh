#!/bin/bash

set -e
SCRIPT_DIR="$(realpath "$(dirname "$0")")"
source "${SCRIPT_DIR}"/../util/args.sh "$@"

# Configure.
cmake \
    -DCMAKE_BUILD_TYPE=RelWithDebInfo \
    -DCMAKE_CUDA_COMPILER="${CUDA_PATH}/bin/nvcc" \
    -DCUDA_TOOLKIT_ROOT_DIR="${CUDA_PATH}" \
    -DAF_BUILD_OPENCL=OFF \
    -DAF_BUILD_CUDA=ON \
    -DAF_BUILD_DOCS=OFF \
    -DAF_BUILD_ONEAPI=OFF \
    -DAF_WITH_CUDNN=OFF \
    -DAF_WITH_NONFREE=ON \
    -DAF_WITH_FMT_HEADER_ONLY=ON \
    -B"${OUT_DIR}/arrayfire/arrayfire/build" \
    "${OUT_DIR}/arrayfire/arrayfire"

# Build.
if [ "${VERBOSE}" == "1" ] ; then
    VERBOSE="VERBOSE=1"
else
    VERBOSE=
fi

make -C "${OUT_DIR}/arrayfire/arrayfire/build" -j"${BUILD_JOBS}" ${VERBOSE}
