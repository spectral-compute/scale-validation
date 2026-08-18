#!/bin/bash

set -e

source "$(dirname "$0")"/../util/git.sh

GROMACS_VER="$(get_version gromacs)"

GMX_SIMD=Auto
if [ "${NO_TUNE_NATIVE:-0}" == "1" ]; then
    # Reasonably portable, should be a superset of x86_64-v3
    GMX_SIMD=AVX2_256
fi

args=(
    # The compute capability we are pretending our target has.
    # This doesn't directly correspond to the AMD GPU: see
    # https://docs.scale-lang.com/stable/manual/library/compute-capabilities/
    -DGMX_CUDA_TARGET_SM=86
    -DCMAKE_CUDA_ARCHITECTURES=${CUDAARCHS}

    # Increase the test timeout a bit. This is useful especialy when running on
    # smaller/consumer cards, and makes sure we actually get benchmark results even if they're really bad
    -DGMX_TEST_TIMEOUT_FACTOR=4

    # Not fully supported by SCALE
    -DGMX_DISABLE_CUDA_TEXTURES=ON
    -DGMX_HAVE_GPU_GRAPH_SUPPORT=OFF

    # Actually use the CUDA backend, but not the clang dialect
    -DGMX_GPU=CUDA
    -DGMX_CLANG_CUDA=OFF

    # Boring CMake configuration
    -DCMAKE_INSTALL_PREFIX="install"
    -DCMAKE_BUILD_TYPE=RelWithDebInfo
    -DGMX_SIMD=$GMX_SIMD

    # Build
    -DGMX_BUILD_OWN_FFTW=ON

    # Build a thread-MPI-based multithreaded version of GROMACS, not using regular MPI
    -DCMAKE_DISABLE_FIND_PACKAGE_MPI=ON
    -DGMX_THREAD_MPI=ON
    -DGMX_OPENMP=OFF
    -DGMX_MPI=OFF

    # Don't build some stuff we don't need
    -DGMX_PYTHON_PACKAGE=OFF
    -DGMX_PYTHON_BINDINGS=OFF
    -DGMX_NNPOT=OFF
)

cmake \
    "${args[@]}" \
    -B"build" \
    "gromacs"

make -O -C build -j"$(nproc)" install
