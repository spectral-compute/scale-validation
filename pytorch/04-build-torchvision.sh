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

cd vision
python -m pip install -v --no-build-isolation --no-deps -e .
