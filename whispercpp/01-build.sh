#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh

args=(
    -DCMAKE_BUILD_TYPE=Release
    -DCMAKE_CUDA_COMPILER="nvcc"
    -DCMAKE_CUDA_ARCHITECTURES="${CUDAARCHS}"
    -DGGML_CCACHE=OFF
    -DCMAKE_CUDA_STANDARD=17

    -DGGML_CUDA=ON
    -DGGML_CUDA_NO_PEER_COPY=ON

    # Build and run happen on different machines in the container pipeline, so native CPU
    # tuning bakes in instructions the run host may not support -- causes SIGILL (see
    # UppASD/01-patch.sh's identical note; llama.cpp/02-build.sh already does the same).
    -DGGML_NATIVE=OFF
)
cmake \
    "${args[@]}" \
    -B"build" \
    "whispercpp"

make -O -C "build" -j"$(nproc)"
