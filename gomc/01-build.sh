#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh

# Compile for the architectures we want.
sed -E "s/set\(CMAKE_CUDA_ARCHITECTURES [^)]*\)/set(CMAKE_CUDA_ARCHITECTURES ${CUDAARCHS})/" \
    -i GOMC/CMake/GOMCCUDASetup.cmake
sed -E "s/(\s+CUDA_ARCHITECTURES ).*/\1${CUDAARCHS}/" -i GOMC/test/BuildGPUTests.cmake

# GOMC's OpenMP support tests __GNUC__'s value. Even if I set this to a larger value that causes use of the newer OpenMP
# syntax Clang expects (by default, at least), it still results in error messages.
sed -E 's/find_package\(OpenMP\)//' -i "GOMC/CMakeLists.txt"

args=(
    -DCMAKE_BUILD_TYPE=Release
    -DCMAKE_CUDA_COMPILER="nvcc"
    -DCMAKE_CXX_FLAGS="-fPIC"
    -DCMAKE_CUDA_FLAGS="-fPIC"
    -DCMAKE_CUDA_ARCHITECTURES="${CUDAARCHS}"
    -DCMAKE_INSTALL_PREFIX="install"

    -DGOMC_GTEST=On
)

cmake \
    "${args[@]}" \
    -B"build" \
    "GOMC"

make -O -C "build" -j"$(nproc)"
