#!/usr/bin/env bash

set -euo pipefail

cmake \
    -GNinja \
    -DCMAKE_BUILD_TYPE=Release \
    -DBLA_VENDOR="Intel10_64lp" \
    -DCMAKE_CUDA_ARCHITECTURES="${CUDAARCHS}" \
    -DCMAKE_CUDA_COMPILER="nvcc" \
    -DCUDA_ENABLED="true" \
    -DDOWNLOAD_ENABLED="false" \
    -DUNINSTALL_ENABLED="false" \
    -DTESTS_ENABLED="true" \
    "colmap"
