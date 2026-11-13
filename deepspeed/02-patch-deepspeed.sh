#!/bin/bash

set -ETeuo pipefail

SCRIPT_DIR="$(dirname "$(realpath "$0")")"

# The Evoformer test's absolute tolerance is below one bf16 ulp at its gradients' magnitudes, so it
# fails for about a quarter of random inputs on NVIDIA too.
git -C DeepSpeed apply "${SCRIPT_DIR}/patches/0001-evoformer-test-relative-tolerance.patch"

# PyTorch is built without NCCL.
sed -Ee 's|^    if sys.platform != "win32":$|    if sys.platform != "win32" and hasattr(torch._C, "_nccl_version"):|' \
    -i DeepSpeed/setup.py
grep -q 'hasattr(torch._C, "_nccl_version")' DeepSpeed/setup.py

# Tests use NCCL; fall back to gloo.
sed -Ee 's|^    backend = get_accelerator\(\).communication_backend_name\(\)$|    backend = get_accelerator().communication_backend_name() if torch.distributed.is_nccl_available() else "gloo"|' \
    -i DeepSpeed/tests/unit/common.py
grep -q 'is_nccl_available() else "gloo"' DeepSpeed/tests/unit/common.py
