#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh

args=(
    -DCMAKE_CUDA_COMPILER="nvcc"
    -DCMAKE_CUDA_ARCHITECTURES="${CUDAARCHS}"
    -DCMAKE_BUILD_TYPE=Release
    -DCMAKE_INSTALL_PREFIX="install"

    -DGGML_CUDA=ON
    -DGGML_NATIVE=OFF

    -DLLAMA_BUILD_UI=OFF
)

cmake \
    "${args[@]}" \
    -B"build" \
    "llama.cpp"

make -O -C "build" install -j"$(nproc)"
