#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh

args=(
    -DCMAKE_BUILD_TYPE=Release
    -DCMAKE_CXX_FLAGS="-Wno-stringop-overread -Wno-format-truncation"
    -DCMAKE_CUDA_ARCHITECTURES="${CUDAARCHS}"
    -DCMAKE_CUDA_COMPILER="nvcc"
)
cmake \
    "${args[@]}" \
    -B"build" \
    "alien"

# Build.
cmake --build "build" -j"$(nproc)"
