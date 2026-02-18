#!/bin/bash

set -e

# This is incredibly cursed, but it's the official instructions!
# This generates part of the cmake build system using make.
echo -e "BACKEND = cuda\nFORT = true\nGPU_TARGET=sm_${CUDAARCHS}" > MAGMA/make.inc
make -C MAGMA -j"$(nproc)" generate

sed -i"" -Ee 's|find_package\( *OpenMP *\)||g' "MAGMA/CMakeLists.txt"

# Configure.
cmake \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX="${OUT_DIR}/MAGMA/MAGMA/inst" \
    -DCMAKE_CUDA_COMPILER="nvcc" \
    -DCMAKE_C_COMPILER="clang" \
    -DCMAKE_CXX_COMPILER="clang++" \
    -DCMAKE_CUDA_ARCHITECTURES="${CUDAARCHS}" \
    -DMAGMA_ENABLE_CUDA=ON \
    -B"build" \
    "MAGMA"

make -C "build" -j"$(nproc)"
