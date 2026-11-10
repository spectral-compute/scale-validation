#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh

# DEM-Engine hints find_package(CUB) at ${CUDAToolkit_ROOT}/lib64/cmake/cub, but CUDAToolkit_ROOT is an
# input that nothing sets. On NVIDIA targets, CUB is only in the CUDA install, so pass it explicitly.
cmake -B build -S DEM-Engine \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_CUDA_COMPILER=nvcc \
    -DCMAKE_CUDA_ARCHITECTURES="${CUDAARCHS}" \
    -DCUDAToolkit_ROOT="${CUDA_PATH}" \
    -GNinja

# -k 0: build as much as possible, for more signal on what's unsupported.
ninja -C build -k 0
