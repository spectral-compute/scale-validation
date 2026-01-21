#!/bin/bash

set -e

# Configure.
cmake \
    -DUSE_CUDNN=OFF \
    -DUSE_OPENCV=OFF \
    -DBUILD_python=off \
    -DBLAS=Open \
    -DBUILD_docs=OFF \
    -DCUDA_ARCH_NAME=Manual \
    -DCUDA_ARCH_BIN="${GPU_ARCH}" \
    -DCUDA_ARCH_PTX="${GPU_ARCH}" \
    -DCUDA_TOOLKIT_ROOT_DIR="${CUDA_PATH}" \
    -DCMAKE_C_COMPILER="${CUDA_PATH}/bin/gcc" \
    -DCMAKE_CXX_COMPILER="${CUDA_PATH}/bin/g++" \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX="$(pwd)/../install" \
    -Dpython_version=3 \
    -B"build" \
    caffe

make -C build -j"$(nproc)" install
make -C build -j"$(nproc)" test.testbin
