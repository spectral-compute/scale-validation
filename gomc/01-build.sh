#!/bin/bash

set -e

# Compile for the architectures we want.
GPU_ARCH="${SCALE_FAKE_CUDA_ARCH}"
for F in GOMC/CMake/GOMCCUDASetup.cmake GOMC/test/BuildGPUTests.cmake ; do
    sed -E "s/(\s+CUDA_ARCHITECTURES ).*/\1${GPU_ARCH}/" -i "GOMC/${F}"
done

# CMake detects that we're Clang, and GOMC enables libc++ for that in a way that seems to be broken.
for F in GOMC/CMakeLists.txt GOMC/lib/cereal-1.3.0/CMakeLists.txt ; do
    sed -E 's/-stdlib=libc[+][+]//' -i "GOMC/${F}"
done

# GOMC's OpenMP support tests __GNUC__'s value. Even if I set this to a larger value that causes use of the newer OpenMP
# syntax Clang expects (by default, at least), it still results in error messages.
sed -E 's/find_package\(OpenMP\)//' -i "GOMC/CMakeLists.txt"

# Fix the call to Difference to be non-ambiguous (needed on Nvidia too).
sed -E 's/ Difference/ ::Difference/g' -i "GOMC/src/GPU/CalculateForceCUDAKernel.cu"

# Configure.
cmake \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_CUDA_COMPILER="${CUDA_PATH}/bin/nvcc" \
    -DCMAKE_CXX_FLAGS="-fPIC" \
    -DCMAKE_CUDA_FLAGS="-fPIC" \
    -DCMAKE_CUDA_ARCHITECTURES="${GPU_ARCH}" \
    -DGOMC_GTEST=On \
    -DCMAKE_INSTALL_PREFIX="install" \
    -B"build" \
    "GOMC"

make -C "$build" -j"$(nproc)"
