#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh

source "${SCRIPT_DIR}/util/env.sh"
# This vllm needs PyTorch 2.13.
source "${SCRIPT_DIR}/../util/pytorch-venv.sh" pytorch-2.13

pytorch_constraints constraints.txt

python -m pip install -c constraints.txt -r vllm/requirements/build/cuda.txt
python -m pip install -c constraints.txt --no-build-isolation -v ./vllm
