#!/bin/bash

set -ETeuo pipefail

SCRIPT_DIR="$(realpath "$(dirname "$0")")"
source "${SCRIPT_DIR}"/../util/args.sh "$@"

# Disable nccl. The makefile uses dpkg and grep to see if it's installed, which makes
# it false-positive on any package with the substring "nccl" in its name (such as
# `libvncclient1`. Lulz.
export NO_MULTI_GPU=1

cd "${OUT_DIR}/llm.c/llm.c"
chmod u+x ./dev/download_starter_pack.sh
./dev/download_starter_pack.sh

# TODO: Needs several things, this may not be an exhaustive list:
# - https://gitlab.com/spectral-ai/engineering/cuda/platform/redscale/-/issues/121
# - https://gitlab.com/spectral-ai/engineering/cuda/platform/redscale/-/issues/329
#make train_gpt2cu

# Build the old version, at least!
make train_gpt2fp32cu
