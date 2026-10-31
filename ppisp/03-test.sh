#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh

source .venv/bin/activate

# Upstream's tests compare the CUDA kernels against a PyTorch reference and torch.autograd.gradcheck.
cd ppisp
python -m pytest tests/ -v
