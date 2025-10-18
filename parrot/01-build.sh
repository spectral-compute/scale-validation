#!/bin/bash

set -e
SCRIPT_DIR="$(realpath "$(dirname "$0")")"
source "${SCRIPT_DIR}"/../util/args.sh "$@"

# Configure.
cmake \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_C_COMPILER="${CUDA_PATH}/bin/clang" \
    -DCMAKE_CXX_COMPILER="${CUDA_PATH}/bin/clang++" \
    -B"${OUT_DIR}/parrot/parrot/build" \
    "${OUT_DIR}/parrot/parrot"

make -C "${OUT_DIR}/parrot/parrot/build" -j"${BUILD_JOBS}"
