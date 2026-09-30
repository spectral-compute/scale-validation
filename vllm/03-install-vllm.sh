#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh

source "${SCRIPT_DIR}/util/env.sh"
source "${SCRIPT_DIR}/../util/pytorch-venv.sh"

pytorch_constraints constraints.txt

python -m pip install -c constraints.txt -r vllm/requirements/build.txt
python -m pip install -c constraints.txt --no-build-isolation -v ./vllm
