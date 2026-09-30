#!/bin/bash

set -ETeuo pipefail

# Upstream's way to build against an existing torch: drop the torch pins.
cd vllm
python3 use_existing_torch.py

# SCALE's nvcc rejects -V.
sed -Ee 's|"/bin/nvcc", "-V"\]|"/bin/nvcc", "--version"]|' -i setup.py
! grep -q '"-V"' setup.py
