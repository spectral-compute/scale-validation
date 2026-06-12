#!/bin/bash

set -ETeuo pipefail

export LD_LIBRARY_PATH="$(realpath install/lib):${LD_LIBRARY_PATH:-}"

# GGML_CUDA_DISABLE_GRAPHS=1: as in 03-test.sh, works around a known issue (tracked internally).
GGML_CUDA_DISABLE_GRAPHS=1 ./install/bin/llama-bench -m "models/llama-2-7b.Q4_0.gguf"
