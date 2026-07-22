#!/usr/bin/env bash
set -euo pipefail

source pytorch/.venv/bin/activate

# TODO(#1144): Kill each of these.
#
# Pytorch tries to use and other GPUs leading to errors.
export CUDA_VISIBLE_DEVICES="${CUDA_VISIBLE_DEVICES:-0}"

# FIXME: This can hopefully be imminently deleted. Something weird is happening
# with dependencies: it seemed that this install call was required or else mnist
# complained about not being able to find pillow (PIL), but reading the log
# after adding this call, the dependency is already satisfied and the example
# happily runs.
python -m pip install pillow

EPOCHS="${EPOCHS:-5}"

cd examples/mnist
python main.py --epochs "$EPOCHS"
