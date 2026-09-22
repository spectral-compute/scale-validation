#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh
raise_error_if_using_rocm

args=(
    -DCMAKE_BUILD_TYPE=Release
    -DCMAKE_CUDA_ARCHITECTURES="${CUDAARCHS}"
    -DCMAKE_INSTALL_PREFIX="$(pwd)/install"
)

cmake \
    "${args[@]}" \
    -B"build" \
    "cuda-samples"

make -O -C "build" -j"$(nproc)"
