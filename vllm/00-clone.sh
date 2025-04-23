#!/bin/bash

set -e
source "$(dirname "$0")"/../util/args.sh "$@"

mkdir -p "${OUT_DIR}/vllm"
cd "${OUT_DIR}/vllm"

do_clone vllm https://github.com/vllm-project/vllm.git v0.6.3
