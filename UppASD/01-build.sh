#!/bin/bash

set -e
SCRIPT_DIR="$(realpath "$(dirname "$0")")"
source "${SCRIPT_DIR}"/../util/args.sh "$@"

# Configure.
cmake \
    -DCMAKE_BUILD_TYPE=TESTING \
    -DCMAKE_C_COMPILER="${CUDA_PATH}/bin/clang" \
    -DCMAKE_CXX_COMPILER="${CUDA_PATH}/bin/clang++" \
    -DCMAKE_INSTALL_PREFIX="${OUT_DIR}/UppASD/UppASD/inst" \
    -DUSE_OPENMP=ON \
    -DUSE_CUDA=ON \
    -B"${OUT_DIR}/UppASD/UppASD/build" \
    "${OUT_DIR}/UppASD/UppASD"

make -C "${OUT_DIR}/UppASD/UppASD/build" -j"$(nproc)"
