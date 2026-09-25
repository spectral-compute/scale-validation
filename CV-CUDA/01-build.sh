#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh

args=(
    -DCMAKE_BUILD_TYPE=Release
    -DCMAKE_INSTALL_PREFIX="install"
    -DCMAKE_CUDA_ARCHITECTURES="${CUDAARCHS}"
    -DCMAKE_CXX_COMPILER="nvcc"

    -DCMAKE_CXX_FLAGS="-w -ferror-limit=0 -fcuda-nvcc-emulation -D__host__=\"__attribute__((host))\" -D__device__=\"__attribute__((device))\""

    -DBUILD_TESTS=ON
)

cmake \
    "${args[@]}" \
    -B"build" \
    "CV-CUDA"

make -O -C "build" -j"$(nproc)"
