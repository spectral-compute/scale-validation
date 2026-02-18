#!/bin/bash

set -e

# Configure.
cmake \
    -DCMAKE_BUILD_TYPE=Release \
    -DCUDA_TOOLKIT_ROOT_DIR=${CUDA_PATH} \
    -DCMAKE_CUDA_COMPILER="nvcc" \
    -DCMAKE_C_COMPILER="clang" \
    -DCMAKE_CXX_COMPILER="clang++" \
    -DCMAKE_CUDA_HOST_COMPILER="clang++" \
    -DOPENMP_RUNTIME=COMP \
    -DWITH_MKL=OFF \
    -DCUDA_NVCC_FLAGS="-Wno-pass-failed -Wno-deprecated-builtins -Wno-unused-result -Wno-missing-braces -Wno-unused-parameter -Wno-sign-compare -Wno-unused-local-typedef" \
    -DCMAKE_CUDA_ARCHITECTURES="${CUDAARCHS}" \
    -DCUDA_ARCH_LIST="8.6" \
    -DWITH_CUDA=ON \
    -DBUILD_TESTS=ON \
    -B"build" \
    "ctranslate2"

make -C "build" -j"$(nproc)"
