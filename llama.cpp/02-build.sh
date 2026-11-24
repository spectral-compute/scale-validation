#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh

args=(
    -DCMAKE_CUDA_COMPILER="nvcc"
    -DCMAKE_CUDA_ARCHITECTURES="${CUDAARCHS}"
    -DCMAKE_BUILD_TYPE=Release
    -DCMAKE_INSTALL_PREFIX="install"

    -DGGML_CUDA=ON
    -DGGML_NATIVE=OFF

    # Don't download the prebuilt web UI either: it's a floating "latest" archive that
    # can stop matching this release (it did on 2026-11-17).
    -DLLAMA_BUILD_UI=OFF
    -DLLAMA_USE_PREBUILT_UI=OFF
)

cmake \
    "${args[@]}" \
    -B"build" \
    "llama.cpp"

make -O -C "build" install -j"$(nproc)"
