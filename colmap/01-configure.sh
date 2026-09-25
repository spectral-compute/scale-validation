#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh

args=(
    -GNinja
    -DCMAKE_BUILD_TYPE=Release
    -DBLA_VENDOR="Intel10_64lp"
    -DCMAKE_CUDA_ARCHITECTURES="${CUDAARCHS}"
    -DCMAKE_CUDA_COMPILER="nvcc"
    -DCUDA_ENABLED="true"
    -DDOWNLOAD_ENABLED="false"
    -DUNINSTALL_ENABLED="false"
    -DTESTS_ENABLED="true"
)

cmake \
    "${args[@]}" \
    -S"colmap" \
    -B"build"
