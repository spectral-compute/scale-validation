#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh

args=(
    -DCMAKE_BUILD_TYPE=Release
    -DCMAKE_CUDA_ARCHITECTURES="${CUDAARCHS}"
    -DCMAKE_CUDA_COMPILER="nvcc"
    -DCMAKE_CUDA_FLAGS="-Wno-unused-result -Wno-deprecated-declarations"
)

cmake \
    "${args[@]}" \
    -B"build" \
    "cudahandbook"

make -O -C "build" -j"$(nproc)"
