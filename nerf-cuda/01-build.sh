#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh
raise_error_if_using_rocm

args=(
    -DCMAKE_BUILD_TYPE=Release
    -DCMAKE_CUDA_COMPILER="nvcc"
    -DCMAKE_C_COMPILER="clang"
    -DCMAKE_CXX_COMPILER="clang++"
    -DCMAKE_CUDA_ARCHITECTURES="${CUDAARCHS}"
)
cmake \
    "${args[@]}" \
    -B"build" \
    "nerf-cuda"

make -O -C build -j"$(nproc)"
