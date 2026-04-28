#!/usr/bin/env bash
set -euo pipefail
OUT_DIR="$(realpath .)"
SRC_DIR="${OUT_DIR}/HeCBench"

# Expect CUDAARCHS like 80, 86, 90 — not sm_80
CUDA_ARCH_NUM="${CUDAARCHS#sm_}"
BUILD_DIR="${SRC_DIR}/build/cuda-sm${CUDA_ARCH_NUM}"

cmake -S "${SRC_DIR}" -B "${BUILD_DIR}" -G Ninja \
    -DCMAKE_CUDA_COMPILER=nvcc \
    -DCMAKE_CUDA_ARCHITECTURES="${CUDA_ARCH_NUM}" \
    -DHECBENCH_CUDA_ARCH="${CUDA_ARCH_NUM}" \
    -DHECBENCH_ENABLE_HIP=OFF \
    -DHECBENCH_ENABLE_SYCL=OFF \
    -DHECBENCH_ENABLE_OPENMP=OFF

# If you need to continue even if some targets fail add to ninja "|| true"
ninja -C "${BUILD_DIR}" -k 0
