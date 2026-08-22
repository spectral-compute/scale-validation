#!/bin/bash

set -ETeuo pipefail

EXTRA_CMAKE_ARGS=()
if [ "$(basename "$(realpath "$(which nvcc)")")" == "clang" ] ; then
    EXTRA_CMAKE_ARGS+=(
        "-DCMAKE_C_COMPILER=$(realpath "$(which nvcc)")"
        "-DCMAKE_CXX_COMPILER=$(realpath "$(which nvcc)")++"
    )
fi

# Configure.
cmake \
    -DCMAKE_BUILD_TYPE=Release \
    -DQUDA_TARGET_TYPE="CUDA" \
    -DCMAKE_CUDA_ARCHITECTURES="${CUDAARCHS}" \
    -DQUDA_GPU_ARCH="${CUDAARCHS}" \
    -DCMAKE_INSTALL_PREFIX="install" \
    "${EXTRA_CMAKE_ARGS[@]}" \
    -B"build" \
    "quda"

make -O -C "build" install -j"$(nproc)"
