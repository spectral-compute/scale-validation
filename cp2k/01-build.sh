#!/usr/bin/env bash

set -euo

cmake \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_CUDA_COMPILER="nvcc" \
    -DCMAKE_CUDA_ARCHITECTURES="${CUDAARCHS}" \
    -DCP2K_USE_EVERYTHING=OFF \
    -DCP2K_USE_ACCEL=CUDA \
    -DCP2K_USE_CUDA=ON \
    -DCP2K_USE_MPI=OFF \
    -DCP2K_USE_LIBXSMM=OFF \
    -DCP2K_USE_LIBXC=OFF \
    -DCP2K_USE_LIBINT2=OFF \
    -DCP2K_USE_FFTW3=OFF \
    -DCP2K_ENABLE_DBM_GPU=ON \
    -DCP2K_ENABLE_GRID_GPU=ON \
    -DCP2K_ENABLE_PW_GPU=ON \
    -DCP2K_DBCSR_USE_CPU_ONLY=OFF \
    -B"build" \
    "cp2k"

make -O -C "build" -j"$(nproc)" cp2k-bin
