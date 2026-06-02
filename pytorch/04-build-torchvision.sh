#!/bin/bash

set -ETeuo pipefail

cd pytorch
source .venv/bin/activate

# Remove any previously installed incompatible torchvision
python -m pip uninstall -y torchvision || true

python -m pip install --upgrade numpy pillow ninja
python -m pip install "setuptools==81.0.0"

if [[ ! -d "vision" ]]; then
    source $(dirname $0)/../util/git.sh
    do_clone vision https://github.com/pytorch/vision.git v0.24.0
fi

# PyTorch has its own env var to set the CUDA compiler
export PYTORCH_NVCC=${CUDACXX}

# --generate-dependencies-with-compile is not a valid clang option
export TORCH_EXTENSION_SKIP_NVCC_GEN_DEPENDENCIES=1

cd vision
python -m pip install -v --no-build-isolation --no-deps -e .
