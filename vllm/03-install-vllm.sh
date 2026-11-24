#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh

source "${SCRIPT_DIR}/util/env.sh"
# This vllm needs PyTorch 2.13.
source "${SCRIPT_DIR}/../util/pytorch-venv.sh" pytorch-2.13

pytorch_constraints constraints.txt

python -m pip install -c constraints.txt -r vllm/requirements/build/cuda.txt
python -m pip install -c constraints.txt --no-build-isolation -v ./vllm

# SCALE's Triton backend, which SCALE for AMD GPUs ships with each target (TRITON_ATTN, torch.compile): Triton's own
# backends make NVIDIA code or need HIP. Installed from a copy, as pip builds in the source directory.
TRITON_SCALE="${CUDA_HOME}/share/scale/triton"
if [[ -d "${TRITON_SCALE}" ]]; then
    rm -rf triton-scale
    cp -r "${TRITON_SCALE}" triton-scale
    python -m pip install --no-build-isolation ./triton-scale
fi
