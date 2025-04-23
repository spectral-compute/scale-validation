#!/bin/bash

set -ETeuo pipefail
source "$(dirname "$0")"/../util/args.sh "$@"
cd "${OUT_DIR}/llama.cpp/install/bin"

./llama-bench -m "${OUT_DIR}/llama.cpp/models/llama-2-7b.Q4_0.gguf"
