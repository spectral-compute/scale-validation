#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh

# Configure.
args=(
    -DCMAKE_BUILD_TYPE=TESTING
    -DCMAKE_C_COMPILER="clang"
    -DCMAKE_CXX_COMPILER="clang++"
    -DCMAKE_CUDA_ARCHITECTURES="${CUDAARCHS}"
    -DCMAKE_INSTALL_PREFIX="inst"

    -DUSE_OPENMP=ON
    -DUSE_CUDA=ON
)
cmake \
    "${args[@]}" \
    -B"build" \
    "UppASD"

make -C "build" -j"$(nproc)"
