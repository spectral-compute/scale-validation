#!/bin/bash

set -e

#for nvcc:
#    -DCMAKE_CXX_COMPILER=$PWD/kokkos/bin/nvcc_wrapper \

cmake \
    -DCMAKE_BUILD_TYPE=Release \
    -DKokkos_ENABLE_CUDA=ON \
    -DKokkos_ARCH_AMPERE86=ON \
    -DCMAKE_CXX_COMPILER=clang++ \
    -DCMAKE_CUDA_FLAGS="-DSCALE_WARP_SIZE=32" \
    -DCMAKE_CXX_FLAGS="-DSCALE_WARP_SIZE=32" \
    -DCMAKE_C_FLAGS="-DSCALE_WARP_SIZE=32" \
    -DKokkos_ENABLE_TESTS=ON \
    -B"build" \
    "kokkos"

make -O -C "build" -j"$(nproc)"
