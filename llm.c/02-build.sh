#!/bin/bash

set -ETeuo pipefail

# Disable nccl. The makefile uses dpkg and grep to see if it's installed, which makes
# it false-positive on any package with the substring "nccl" in its name (such as
# `libvncclient1`. Lulz.
export NO_MULTI_GPU=1

chmod u+x ./llm.c/dev/download_starter_pack.sh
./llm.c/dev/download_starter_pack.sh

# TODO: Needs several things, this may not be an exhaustive list:
# - https://gitlab.com/spectral-ai/engineering/cuda/platform/redscale/-/issues/121
# - https://gitlab.com/spectral-ai/engineering/cuda/platform/redscale/-/issues/329
#make train_gpt2cu

# Build the old version, at least!
make -C llm.c train_gpt2fp32cu
