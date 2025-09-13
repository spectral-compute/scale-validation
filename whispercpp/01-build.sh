#!/bin/bash

set -e
SCRIPT_DIR="$(realpath "$(dirname "$0")")"
source "${SCRIPT_DIR}"/../util/args.sh "$@"

# Configure.
cmake \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_CUDA_COMPILER="${CUDA_PATH}/bin/nvcc" \
    -DCMAKE_CUDA_ARCHITECTURES="$(echo "${GPU_ARCH}" | sed -E 's/sm_//g')" \
    -DGGML_CCACHE=OFF \
    -DGGML_CUDA=ON \
    -DGGML_CUDA_NO_PEER_COPY=ON \
    -B"${OUT_DIR}/whispercpp/whispercpp/build" \
    "${OUT_DIR}/whispercpp/whispercpp"

# Build.
if [ "${VERBOSE}" == "1" ] ; then
    VERBOSE="VERBOSE=1"
else
    VERBOSE=
fi

make -C "${OUT_DIR}/whispercpp/whispercpp/build" -j"${BUILD_JOBS}" ${VERBOSE}
