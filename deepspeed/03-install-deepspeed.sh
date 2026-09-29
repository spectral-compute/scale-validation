#!/bin/bash

set -ETeuo pipefail
SCRIPT_DIR="$(dirname "$(realpath "$0")")"

source "${SCRIPT_DIR}/util/env.sh"
source "${SCRIPT_DIR}/../util/pytorch-venv.sh"

pytorch_constraints constraints.txt

# Ops are JIT-built by 04-test.sh.
python -m pip install -c constraints.txt ./DeepSpeed

# Not requirements-dev.txt: it pulls torchvision and prebuilt deepspeed-kernels.
python -m pip install -c constraints.txt "pytest>=7.2.0,<8.4.0" pytest-forked pytest-xdist

ds_report
