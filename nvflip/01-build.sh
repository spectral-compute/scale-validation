#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh

args=(
    -DCMAKE_BUILD_TYPE=Release
    -DCMAKE_CUDA_FLAGS="-arch=sm_$CUDAARCHS"

    -DFLIP_ENABLE_CUDA=ON
)

cmake \
    "${args[@]}" \
    -B"build" \
    "nvflip/src"

make -O -C "build" -j"$(nproc)"
