#!/bin/bash

set -ETeuo pipefail
source "$(dirname "$0")"/../util/args.sh "$@"
cd "${OUT_DIR}/llama.cpp/install/bin"

export LD_LIBRARY_PATH="${CUDA_DIR}/lib"
./llama-bench -m "${OUT_DIR}/llama.cpp/models/llama-2-7b.Q4_0.gguf"
