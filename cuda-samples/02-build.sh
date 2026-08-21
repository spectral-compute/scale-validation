#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh

args=(
    -DCMAKE_BUILD_TYPE=Release
    -DCMAKE_CUDA_ARCHITECTURES="${CUDAARCHS}"
    -DCMAKE_INSTALL_PREFIX="${OUT_DIR}/cuda-samples/install"
)

cmake \
    "${args[@]}" \
    -B"build" \
    "cuda-samples"

make -O -C "build" -j"$(nproc)"
