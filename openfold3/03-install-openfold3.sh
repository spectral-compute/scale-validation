#!/bin/bash

set -ETeuo pipefail
SCRIPT_DIR="$(dirname "$(realpath "$0")")"

source "${SCRIPT_DIR}/util/env.sh"
source "${SCRIPT_DIR}/../util/pytorch-venv.sh"

pytorch_constraints constraints.txt

# Optional DeepSpeed attention: the deepspeed test's patched checkout (PyPI's doesn't install).
if [ "${OPENFOLD3_DEEPSPEED:-0}" = 1 ] ; then
    DEEPSPEED_DIR="$(realpath ../)/deepspeed/DeepSpeed"
    if [ ! -e "${DEEPSPEED_DIR}" ] ; then
        echo "Please run the DeepSpeed third party project first. Use the same working directory." 1>&2
        exit 1
    fi
    python -m pip install -c constraints.txt "${DEEPSPEED_DIR}"
fi

python -m pip install -c constraints.txt "./openfold-3[dev]"

python - <<PY
import torch
assert torch.__file__.startswith("${PYTORCH_VENV}"), torch.__file__
assert torch.version.hip is None, "expected the SCALE (CUDA) build of PyTorch"
assert torch.cuda.is_available(), "no GPU visible to PyTorch"
print("torch", torch.__version__, "on", torch.cuda.get_device_name(0))
PY

# Model parameters and CCD.
mkdir -p "${OPENFOLD_CACHE}"
cat > setup_config.json <<JSON
{
    "openfold_cache": "${OPENFOLD_CACHE}",
    "param_directory": "${OPENFOLD_CACHE}",
    "selected_parameters": "default",
    "run_integration_tests": false
}
JSON
setup_openfold --config setup_config.json
