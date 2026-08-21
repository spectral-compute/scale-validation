#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh

args=(
    -DCMAKE_BUILD_TYPE=Release
    -DCMAKE_CUDA_COMPILER="nvcc"
    -DCMAKE_CUDA_ARCHITECTURES="${CUDAARCHS}"

    -DFLAMEGPU_BUILD_TESTS=ON
)

cmake \
    "${args[@]}" \
    -B"build" \
    "FLAMEGPU2"

make -O -C "build" -j"$(nproc)"
