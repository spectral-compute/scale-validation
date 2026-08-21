#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh

args=(
    -DCMAKE_BUILD_TYPE=Release
    -DCMAKE_C_COMPILER="clang"
    -DCMAKE_CXX_COMPILER="clang++"
    -DCMAKE_CUDA_ARCHITECTURES="${CUDAARCHS}"
    -DCMAKE_INSTALL_PREFIX="install"

    -DUSE_GPU=ON
    -DUSE_CUDA=ON
    -DBUILD_CPP_TEST=ON
)

cmake \
    "${args[@]}" \
    -B"build" \
    "lightgbm"

make -O -C "build" install -j"$(nproc)"
