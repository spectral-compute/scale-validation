#!/bin/bash

set -e

#for nvcc:
#    -DCMAKE_CXX_COMPILER=$PWD/kokkos/bin/nvcc_wrapper \

cmake \
    -DCMAKE_BUILD_TYPE=Release \
    -DKokkos_ENABLE_CUDA=ON \
    -DKokkos_ARCH_ADA89=ON \
    -DCMAKE_CXX_COMPILER=clang++ \
    -DKokkos_ENABLE_TESTS=ON \
    -B"build" \
    "kokkos"

make -C "build" -j"$(nproc)"
