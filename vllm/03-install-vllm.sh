#!/bin/bash

set -ETeuo pipefail
SCRIPT_DIR="$(dirname "$(realpath "$0")")"

source "${SCRIPT_DIR}/util/env.sh"
source "${SCRIPT_DIR}/../util/pytorch-venv.sh"

pytorch_constraints constraints.txt

python -m pip install -c constraints.txt -r vllm/requirements/build.txt
python -m pip install -c constraints.txt --no-build-isolation -v ./vllm
