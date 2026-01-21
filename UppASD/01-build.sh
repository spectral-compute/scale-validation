#!/bin/bash

set -e

# Configure.
cmake \
    -DCMAKE_BUILD_TYPE=TESTING \
    -DCMAKE_C_COMPILER="${CUDA_PATH}/bin/clang" \
    -DCMAKE_CXX_COMPILER="${CUDA_PATH}/bin/clang++" \
    -DCMAKE_INSTALL_PREFIX="inst" \
    -DUSE_OPENMP=ON \
    -DUSE_CUDA=ON \
    -B"build" \
    "UppASD"

make -C "build" -j"$(nproc)"
