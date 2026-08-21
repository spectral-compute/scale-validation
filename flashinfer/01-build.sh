#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh

export SCALE_CUDA_VERSION="12.1"

args=(
    -DCMAKE_BUILD_TYPE=Release
    -DCMAKE_C_COMPILER="clang"
    -DCMAKE_CXX_COMPILER="clang++"
    -DCMAKE_CUDA_COMPILER="nvcc"
    -Dflashinfer_NVCC_ARCHS="${CUDAARCHS}"
    -DCMAKE_CUDA_ARCHITECTURES="${CUDAARCHS}"
    -DCMAKE_CUDA_FLAGS="-Wno-unused-result -Wno-deprecated-declarations"

    -DFLASHINFER_ENABLE_FP8=OFF
    -DFLASHINFER_ENABLE_FP8_E4M3=OFF
    -DFLASHINFER_ENABLE_FP8_E5M2=OFF
    -DFLASHINFER_ENABLE_F16=ON
    -DFLASHINFER_ENABLE_BF16=ON
)

cmake \
    "${args[@]}" \
    -B"build" \
    "flashinfer"

cmake --build "build" -j"$(nproc)"
