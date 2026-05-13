#!/usr/bin/env bash
set -euo pipefail

# Pytorch tries to use and other GPUs leading to errors.
export CUDA_VISIBLE_DEVICES="${CUDA_VISIBLE_DEVICES:-0}"

SCRIPT_DIR="$(realpath "$(dirname "$0")")"
OUT_DIR="$(realpath .)"
SRCROOT="${OUT_DIR}/pytorch"
EXAMPLES_DIR="${OUT_DIR}/examples"

PYTHON="${PYTHON:-python}"
MNIST_EPOCHS="${MNIST_EPOCHS:-5}"
IMAGENET_DIR="${IMAGENET_DIR:-}"
IMAGENET_MODELS="${IMAGENET_MODELS:-resnet18}"
#IMAGENET_MODELS="${IMAGENET_MODELS:-resnet18 resnet50 mobilenet_v2}"
IMAGENET_EPOCHS="${IMAGENET_EPOCHS:-5}"
IMAGENET_BATCH_SIZE="${IMAGENET_BATCH_SIZE:-64}"
IMAGENET_WORKERS="${IMAGENET_WORKERS:-8}"

if [[ ! -d "$SRCROOT/.venv" ]]; then
  echo "Could not find .venv in $SRCROOT"
  exit 1
fi

source "$SRCROOT/.venv/bin/activate"

# Clone pytoch examples
if [[ ! -d "$EXAMPLES_DIR/.git" ]]; then
  git clone https://github.com/pytorch/examples.git "$EXAMPLES_DIR"
else
  git -C "$EXAMPLES_DIR" pull
fi

echo "Running MNIST on GPU for $MNIST_EPOCHS epochs..."
cd "$EXAMPLES_DIR/mnist"

"$PYTHON" main.py --epochs "$MNIST_EPOCHS"

echo "MNIST finished."

echo "Checking ImageNet dataset..."
echo "IMAGENET_DIR: $IMAGENET_DIR"

if [[ ! -d "$IMAGENET_DIR" ]]; then
  echo "ERROR: IMAGENET_DIR does not exist or is not a directory:"
  echo "  $IMAGENET_DIR"
  echo
  echo " Use the following to provide the imagenet path:"
  echo "  IMAGENET_DIR=/path/to/imagenet"
  exit 1
fi

if [[ ! -d "$IMAGENET_DIR/train" ]]; then
  echo "Missing ImageNet train directory: $IMAGENET_DIR/train"
  exit 1
fi

if [[ ! -d "$IMAGENET_DIR/val" ]]; then
  echo "Missing ImageNet val directory: $IMAGENET_DIR/val"
  exit 1
fi

echo "Running ImageNet examples on GPU..."
echo "models:     $IMAGENET_MODELS"
echo "epochs:     $IMAGENET_EPOCHS"
echo "batch size: $IMAGENET_BATCH_SIZE"
echo "workers:    $IMAGENET_WORKERS"

cd "$EXAMPLES_DIR/imagenet"

for MODEL in $IMAGENET_MODELS; do
  echo "Running: $MODEL"
  "$PYTHON" main.py \
    -a "$MODEL" "$IMAGENET_DIR" --epochs "$IMAGENET_EPOCHS" \
    -b "$IMAGENET_BATCH_SIZE" -j "$IMAGENET_WORKERS"

  echo "Finished: $MODEL"
done
