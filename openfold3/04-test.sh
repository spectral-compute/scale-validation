#!/bin/bash

set -uo pipefail
SCRIPT_DIR="$(dirname "$(realpath "$0")")"

source "${SCRIPT_DIR}/util/env.sh"
source "${SCRIPT_DIR}/../util/checks.sh"
source "${SCRIPT_DIR}/../util/pytorch-venv.sh"

# Here rather than in the build step, which CI runs without a GPU.
scale_torch() {
    python - <<PY
import torch
assert torch.__file__.startswith("${PYTORCH_VENV}"), torch.__file__
assert torch.version.hip is None, "expected the SCALE (CUDA) build of PyTorch"
assert torch.cuda.is_available(), "no GPU visible to PyTorch"
print("torch", torch.__version__, "on", torch.cuda.get_device_name(0))
PY
}

check "SCALE PyTorch sees the GPU" scale_torch

cd openfold-3

# Asserts the Triton default we turn off.
unit_tests() {
    python -m pytest openfold3/tests -m "not slow" -v -n 8 \
        --deselect openfold3/tests/test_entry_points.py::TestModelUpdate::test_mps_preset_not_applied_when_mps_wont_run
}

# MSA cases need internet (ColabFold server).
integration_tests() {
    python -m pytest openfold3/tests -m slow -v
}

# Ubiquitin accuracy test with DeepSpeed attention; check the kernel was used.
deepspeed_attention() {
    python "${SCRIPT_DIR}/util/ds_attention_test.py" &&
        ls "${TORCH_EXTENSIONS_DIR}"/evoformer_attn/evoformer_attn*.so
}

check "unit tests" unit_tests
check "integration tests" integration_tests
if [ "${OPENFOLD3_DEEPSPEED:-0}" = 1 ] ; then
    check "DeepSpeed attention" deepspeed_attention
fi
check_exit
