#!/bin/bash

set -ETeuo pipefail
SCRIPT_DIR="$(realpath "$(dirname "$0")")"
source "${SCRIPT_DIR}"/../util/args.sh "$@"

# Clean up any previous stuff.
rm -rf "${OUT_DIR}/quda/build"

# Configure.
cmake \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_CUDA_COMPILER="${CUDA_PATH}/bin/nvcc" \
    -DQUDA_TARGET_TYPE="CUDA" \
    -DCMAKE_CUDA_ARCHITECTURES="$(echo "${GPU_ARCH}" | sed -E 's/sm_//g')" \
    -DQUDA_GPU_ARCH="$(echo "${GPU_ARCH}" | sed -E 's/sm_//g')" \
    -DCMAKE_INSTALL_PREFIX="${OUT_DIR}/quda/install" \
    -B"${OUT_DIR}/quda/build" \
    "${OUT_DIR}/quda/quda"

# Make sure we actually found CUDA.
"${SCRIPT_DIR}"/../util/check-cmake-cuda-version.sh "${OUT_DIR}/quda/build"

# Build.
if [ "${VERBOSE}" == "1" ] ; then
    VERBOSE="VERBOSE=1"
else
    VERBOSE=
fi
make -C "${OUT_DIR}/quda/build" install -j"${BUILD_JOBS}" "${VERBOSE}"
