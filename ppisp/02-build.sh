#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh

source "$(dirname "$0")"/../util/pytorch-venv.sh
source .venv/bin/activate

pytorch_constraints constraints.txt

# setup.py otherwise asks the GPU for its architecture, and there's none when CI builds.
if ((${#CUDAARCHS} == 2)); then
    TORCH_CUDA_ARCH_LIST="${CUDAARCHS:0:1}.${CUDAARCHS:1:1}"
else
    TORCH_CUDA_ARCH_LIST="${CUDAARCHS:0:2}.${CUDAARCHS:2:1}"
fi
export TORCH_CUDA_ARCH_LIST

python -m pip install -c constraints.txt -v --no-build-isolation ./ppisp pytest
