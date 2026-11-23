#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh

# This vllm needs PyTorch 2.13.
source "$(dirname "$0")"/../util/pytorch-venv.sh pytorch-2.13

create_pytorch_venv
