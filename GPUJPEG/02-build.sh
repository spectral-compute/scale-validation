#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh

args=(
    -DCMAKE_BUILD_TYPE=Release
    -DCMAKE_CUDA_ARCHITECTURES="${CUDAARCHS}"
    -DCMAKE_CUDA_COMPILER="nvcc"
    -DCMAKE_C_FLAGS="-Wno-error=implicit-function-declaration -Wno-error=implicit-int"
    -DCMAKE_CXX_FLAGS="-Wno-stringop-overread"
    -DCMAKE_CUDA_FLAGS="-Wno-error=implicit-const-int-float-conversion"
)

cmake \
    "${args[@]}" \
    -B"build" \
    "GPUJPEG"

cmake --build "build" -j"$(nproc)"
