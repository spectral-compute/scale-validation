#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh

cmake -B build -S DEM-Engine \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_CUDA_COMPILER=nvcc \
    -DCMAKE_CUDA_ARCHITECTURES="${CUDAARCHS}" \
    -GNinja

# -k 0: build as much as possible, for more signal on what's unsupported.
ninja -C build -k 0
