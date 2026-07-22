#!/usr/bin/env bash
set -euo pipefail

source pytorch/.venv/bin/activate

# TODO(#1144): Kill each of these.
#
# Pytorch tries to use and other GPUs leading to errors.
export CUDA_VISIBLE_DEVICES="${CUDA_VISIBLE_DEVICES:-0}"

EPOCHS="${EPOCHS:-5}"

cd examples/mnist
python -m pip install -r requirements.txt
python main.py --epochs "$EPOCHS"
