#!/bin/bash

set -ETeuo pipefail
SCRIPT_DIR="$(realpath "$(dirname "$0")")"
source "${SCRIPT_DIR}"/../util/args.sh "$@"

# Configure.
cmake \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_CUDA_COMPILER="${CUDA_PATH}/bin/nvcc" \
    -DCMAKE_CUDA_ARCHITECTURES="$(echo "${GPU_ARCH}" | sed -E 's/^sm_//')" \
    -DGGML_CUDA=ON \
    -DCMAKE_INSTALL_PREFIX="${OUT_DIR}/llama.cpp/install" \
    -B"${OUT_DIR}/llama.cpp/build" \
    "${OUT_DIR}/llama.cpp/llama.cpp"

# Make sure we actually found CUDA.
"${SCRIPT_DIR}"/../util/check-cmake-cuda-version.sh "${OUT_DIR}/llama.cpp/build"

# Build.
if [ "${VERBOSE}" == "1" ] ; then
    VERBOSE="VERBOSE=1"
else
    VERBOSE=
fi
make -C "${OUT_DIR}/llama.cpp/build" install -j"${BUILD_JOBS}" ${VERBOSE}
