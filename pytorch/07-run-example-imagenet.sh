#!/usr/bin/env bash
set -euo pipefail

source pytorch/.venv/bin/activate

# TODO(#1144): Kill.
#
# Pytorch tries to use and other GPUs leading to errors.
export CUDA_VISIBLE_DEVICES="${CUDA_VISIBLE_DEVICES:-0}"

cd examples/imagenet
pip install -r requirements.txt

# TODO(#1154): Need to download the imagenet dataset.
extract_ILSVRC.sh

EPOCHS="${EPOCHS:-5}"
BATCH_SIZE="${BATCH_SIZE:-64}"
WORKERS="${WORKERS:-8}"
MODELS="${MODELS:-resnet18 resnet50 mobilenet_v2}"

for MODEL in $MODELS; do
  python main.py \
    -a "$MODEL" "$DIR" --epochs "$EPOCHS" \
    -b "$BATCH_SIZE" -j "$WORKERS"
done
