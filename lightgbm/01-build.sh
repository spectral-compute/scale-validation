#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh

args=(
    -DCMAKE_BUILD_TYPE=Release
    -DCMAKE_CUDA_ARCHITECTURES="${CUDAARCHS}"
    -DCMAKE_INSTALL_PREFIX="install"

    -DUSE_CUDA=ON
)

cmake \
    "${args[@]}" \
    -B"build" \
    "lightgbm"

make -O -C "build" install -j"$(nproc)"
