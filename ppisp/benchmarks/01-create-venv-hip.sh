#!/usr/bin/env bash
# shellcheck source-path=SCRIPTDIR
. "$(dirname "$0")"/../../util/prelude.sh

# Native AMD baseline: PyTorch's ROCm wheel at the version the pytorch test builds.
TORCH_VERSION="$(get_version pytorch)"
python3 -m venv .venv
.venv/bin/python -m pip install setuptools wheel ninja
.venv/bin/python -m pip install "torch==${TORCH_VERSION#v}" \
    --index-url "https://download.pytorch.org/whl/${PYTORCH_ROCM_WHEEL:-rocm6.4}"
