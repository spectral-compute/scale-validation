#!/bin/bash

set -e
SCRIPT_DIR="$(realpath "$(dirname "$0")")"
source "${SCRIPT_DIR}"/../util/args.sh "$@"

# Configure.
cmake \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_C_COMPILER="${CUDA_PATH}/bin/clang" \
    -DCMAKE_CXX_COMPILER="${CUDA_PATH}/bin/clang++" \
    -DSTRINGZILLA_BUILD_TEST=1 \
    -B"${OUT_DIR}/StringZilla/StringZilla/build" \
    "${OUT_DIR}/StringZilla/StringZilla"

make -C "${OUT_DIR}/StringZilla/StringZilla/build" -j"$(nproc)"
