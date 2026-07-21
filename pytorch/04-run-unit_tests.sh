#!/usr/bin/env bash
set -euo pipefail

# TODO(#1144): Kill.
#
# Pytorch tries to use and other GPUs leading to errors.
export CUDA_VISIBLE_DEVICES="${CUDA_VISIBLE_DEVICES:-0}"

cd pytorch
source .venv/bin/activate
python -m pip install -q --upgrade expecttest

SCRIPT_DIR="$(dirname "$(realpath $0)")"
python test/test_torch.py -v $(cat $SCRIPT_DIR/util/cuda-tests.txt)
