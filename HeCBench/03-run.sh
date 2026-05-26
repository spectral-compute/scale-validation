#!/bin/bash
set -u

OUT_DIR="$(realpath .)/HeCBench"

CUDA_ARCH_NUM="${CUDAARCHS#sm_}"

DATA_FILE="$OUT_DIR/hecbench.cuda-sm$CUDA_ARCH_NUM.json"

python3 $OUT_DIR/tools/hecbench run \
  --model cuda \
  --preset scale-cuda-sm$CUDA_ARCH_NUM \
  --store \
  --output "$DATA_FILE"
