#!/bin/bash

set -ETeuo pipefail
SCRIPT_DIR="$(realpath "$(dirname "$0")")"
source "${SCRIPT_DIR}"/../util/args.sh "$@"

# Configure.
cmake \
    -DCMAKE_BUILD_TYPE=Release \
    -DQUDA_TARGET_TYPE="CUDA" \
    -DCMAKE_CUDA_ARCHITECTURES="$(echo "${GPU_ARCH}" | sed -E 's/sm_//g')" \
    -DQUDA_GPU_ARCH="$(echo "${GPU_ARCH}" | sed -E 's/sm_//g')" \
    -DCMAKE_INSTALL_PREFIX="${OUT_DIR}/quda/install" \
    -B"${OUT_DIR}/quda/build" \
    "${OUT_DIR}/quda/quda"

make -C "${OUT_DIR}/quda/build" install -j"${BUILD_JOBS}" "${VERBOSE}"
