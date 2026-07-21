#!/bin/bash
set -ETuo pipefail

OUT_DIR="$(realpath .)"
SRC_DIR="${OUT_DIR}/HeCBench"

# Expect CUDAARCHS like 80, 86, 90 — not sm_80
CUDA_ARCH_NUM="${CUDAARCHS#sm_}"
BUILD_DIR="${SRC_DIR}/build/cuda-sm${CUDA_ARCH_NUM}"

python3 $SRC_DIR/tools/hecbench --verbose build --preset scale-cuda-sm${CUDA_ARCH_NUM}
build_status=$?

if [ "$build_status" -ne 0 ]; then
    echo "hecbench build failed with exit code ${build_status}" >&2
    exit "$build_status"
fi