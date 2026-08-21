#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh

args=(
    -DCMAKE_BUILD_TYPE=Release
    -DCMAKE_CXX_FLAGS="-fpermissive"
    -DCMAKE_CUDA_ARCHITECTURES="${CUDAARCHS}"
    -DBUILD_TESTING=On
    -DPSZ_BUILD_EXAMPLES=On
    -DCMAKE_INSTALL_PREFIX="install"
)

cmake \
    "${args[@]}" \
    -B"build" \
    "cuSZ"

make -O -C "build" install -j"$(nproc)"
