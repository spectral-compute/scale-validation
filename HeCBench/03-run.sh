#!/bin/bash
set -u

OUT_DIR="$(realpath .)/HeCBench"
RESULTS_DIR="/tmp/ci-benchmarks"

CUDA_ARCH_NUM="${CUDAARCHS#sm_}"

TEST_DT=$(date '+%Y%m%d-%H%M%S')

DATA_FILE="hecbench.scale.$TEST_GPU_ARCH.cuda-sm$CUDA_ARCH_NUM.$TEST_DT.csv"

mkdir -p "$RESULTS_DIR"

python3 $OUT_DIR/tools/hecbench run \
  --model cuda \
  --preset scale-cuda-sm$CUDA_ARCH_NUM \
  --store "hecbench-results.scale.$TEST_GPU_ARCH.cuda-sm$CUDA_ARCH_NUM.db" \
  --format csv \
  --output "$RESULTS_DIR/$DATA_FILE"
