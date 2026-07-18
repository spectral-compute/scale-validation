#!/usr/bin/env bash
set -euo pipefail

# Pytorch tries to use and other GPUs leading to errors.
export CUDA_VISIBLE_DEVICES="${CUDA_VISIBLE_DEVICES:-0}"
SCRIPT_DIR="$(realpath "$(dirname "$0")")"
OUT_DIR="$(realpath .)"
SRCROOT="${OUT_DIR}/pytorch"

cd "$SRCROOT"

if [[ ! -d .venv ]]; then
  echo "Could not find .venv in $SRCROOT"
  exit 1
fi

source "$SRCROOT/.venv/bin/activate"
python -m pip install -q --upgrade expecttest
python "$SRCROOT/test/test_torch.py" -v $(cat $SCRIPT_DIR/util/cuda-tests.txt)
