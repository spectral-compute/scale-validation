#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh

args=(
    -DUSE_CUDNN=OFF
    -DUSE_OPENCV=OFF
    -DBUILD_docs=OFF
    -DBUILD_python=off

    -DBLAS=Open

    -DCMAKE_POLICY_VERSION_MINIMUM=3.5
    -Dpython_version=3

    -DCUDA_ARCH_NAME=Manual
    -DCUDA_ARCH_BIN="${CUDAARCHS}"
    -DCUDA_ARCH_PTX="${CUDAARCHS}"
    -DCUDA_TOOLKIT_ROOT_DIR="${CUDA_PATH}"
    -DCMAKE_BUILD_TYPE=Release
    -DCMAKE_INSTALL_PREFIX="$(pwd)/../install"
)

cmake \
    "${args[@]}" \
    -B"build" \
    caffe

make -O -C build -j"$(nproc)" install
make -O -C build -j"$(nproc)" test.testbin
