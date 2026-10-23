#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh

# SGLang (and timm) need torchvision; PyPI's would replace our torch.
source "${SCALE_VALIDATION}/pytorch/util/build-env.sh"
source .venv/bin/activate

python -m pip install --no-build-isolation -v ./vision
