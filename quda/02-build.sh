#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh

args=(
    -DCMAKE_BUILD_TYPE=Release
    -DCMAKE_CUDA_ARCHITECTURES="${CUDAARCHS}"
    -DCMAKE_INSTALL_PREFIX="install"

    -DQUDA_TARGET_TYPE="CUDA"
    -DQUDA_GPU_ARCH="${CUDAARCHS}"

)
cmake \
    "${args[@]}" \
    -B"build" \
    "quda"

make -O -C "build" install -j"$(nproc)"
