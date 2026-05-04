#!/bin/bash

set -e

GROMACS_VER=2025.4

GMX_SIMD=Auto
if [ "${NO_TUNE_NATIVE:-0}" == "1" ]; then
    # Reasonably portable, should be a superset of x86_64-v3
    GMX_SIMD=AVX2_256
fi

# Configure.
cmake \
    -DGMX_TEST_TIMEOUT_FACTOR=4 \
    -DGMX_DISABLE_CUDA_TEXTURES=ON \
    -DCMAKE_INSTALL_PREFIX="install" \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_CUDA_ARCHITECTURES=${CUDAARCHS} \
    -DGMX_CUDA_TARGET_SM=${CUDAARCHS} \
    -DGMX_CLANG_CUDA=OFF \
    -DGMX_GPU=CUDA \
    -DGMX_BUILD_OWN_FFTW=ON \
    -DGMX_PYTHON_PACKAGE=OFF \
    -DGMX_MPI=OFF \
    -DGMX_PYTHON_BINDINGS=OFF \
    -DGMX_THREAD_MPI=ON \
    -DCMAKE_DISABLE_FIND_PACKAGE_MPI=ON \
    -DGMX_HAVE_GPU_GRAPH_SUPPORT=OFF \
    -DGMX_NNPOT=OFF  \
    -DGMX_OPENMP=OFF \
    -DGMX_SIMD=$GMX_SIMD \
    -B"build" \
    "gromacs"

make -C build -j"$(nproc)" install
