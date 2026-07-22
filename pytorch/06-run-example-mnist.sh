#!/usr/bin/env bash
set -euo pipefail

source pytorch/.venv/bin/activate

# TODO(#1144): Kill each of these.
#
# Pytorch tries to use and other GPUs leading to errors.
export CUDA_VISIBLE_DEVICES="${CUDA_VISIBLE_DEVICES:-0}"

# mnist's requirements.txt only lists torch and torchvision. It should be a
# noop to install deps via this file, except for pulling in deps, but rather
# than risk having something break and CI mistakenly installing and running
# the pip pytorch, let's just install pillow.
python -m pip install pillow

EPOCHS="${EPOCHS:-5}"

cd examples/mnist
python main.py --epochs "$EPOCHS"
