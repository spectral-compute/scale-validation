#!/bin/bash
set -euo pipefail
OUT_DIR="$(realpath .)"
SRC_DIR="${OUT_DIR}/HeCBench"

# Expect CUDAARCHS like 80, 86, 90 — not sm_80
CUDA_ARCH_NUM="${CUDAARCHS#sm_}"
BUILD_DIR="${SRC_DIR}/build/cuda-sm${CUDA_ARCH_NUM}"

python3 $SRC_DIR/tools/hecbench --verbose build --preset scale-cuda-sm${CUDA_ARCH_NUM}

# python3 $SRC_DIR/tools/generate_metadata.py -o $BUILD_DIR/benchmark_input_config.yaml
