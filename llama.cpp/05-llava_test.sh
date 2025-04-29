#!/bin/bash

set -ETeuo pipefail
source "$(dirname "$0")"/../util/args.sh "$@"

cd "${OUT_DIR}/llama.cpp/install/bin"
./llava-cli -m "${OUT_DIR}/llama.cpp/models/ggml-model-q5_k.gguf" --mmproj "${OUT_DIR}/llama.cpp/models/mmproj-model-f16.gguf" --image "${OUT_DIR}/llama.cpp/house.jpg" -p "describe the image in detail. In English" --temp 0.1 -ngl 99
