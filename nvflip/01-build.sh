#!/bin/bash

set -e
SCRIPT_DIR="$(realpath "$(dirname "$0")")"
source "${SCRIPT_DIR}"/../util/args.sh "$@"

# Configure.
cmake \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_C_COMPILER="${CUDA_PATH}/bin/clang" \
    -DCMAKE_CXX_COMPILER="${CUDA_PATH}/bin/clang++" \
    -DCMAKE_CXX_FLAGS="-Wno-error=c++11-narrowing" \
    -DFLIP_ENABLE_CUDA=ON \
    -B"${OUT_DIR}/nvflip/nvflip/build" \
    "${OUT_DIR}/nvflip/nvflip/src"

make -C "${OUT_DIR}/nvflip/nvflip/build" -j"${BUILD_JOBS}"
