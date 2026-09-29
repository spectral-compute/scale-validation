#!/bin/bash

set -ETeuo pipefail

# SCALE's nvcc rejects -V.
sed -Ee 's|"/bin/nvcc", "-V"\]|"/bin/nvcc", "--version"]|' -i DeepSpeed/deepspeed/env_report.py
sed -Ee 's|\[nvcc, "-V"\]|[nvcc, "--version"]|' -i DeepSpeed/op_builder/builder.py
! grep -q '"-V"' DeepSpeed/deepspeed/env_report.py DeepSpeed/op_builder/builder.py

# PyTorch is built without NCCL.
sed -Ee 's|^    if sys.platform != "win32":$|    if sys.platform != "win32" and hasattr(torch._C, "_nccl_version"):|' \
    -i DeepSpeed/setup.py
grep -q 'hasattr(torch._C, "_nccl_version")' DeepSpeed/setup.py

# Tests use NCCL; fall back to gloo.
sed -Ee 's|^    backend = get_accelerator\(\).communication_backend_name\(\)$|    backend = get_accelerator().communication_backend_name() if torch.distributed.is_nccl_available() else "gloo"|' \
    -i DeepSpeed/tests/unit/common.py
grep -q 'is_nccl_available() else "gloo"' DeepSpeed/tests/unit/common.py
