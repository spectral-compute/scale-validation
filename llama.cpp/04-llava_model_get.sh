#!/bin/bash

set -ETeuo pipefail
source "$(dirname "$0")"/../util/args.sh "$@"

cp house.jpg "${OUT_DIR}/llama.cpp/house.jpg"

cd "${OUT_DIR}/llama.cpp/models"
if [ ! -e "ggml-model-q5_k.gguf" ]; then
	wget https://huggingface.co/mys/ggml_llava-v1.5-7b/resolve/main/ggml-model-q5_k.gguf?download=true -O ggml-model-q5_k.gguf
fi
if [ ! -e "mmproj-model-f16.gguf" ]; then
	wget https://huggingface.co/mys/ggml_llava-v1.5-7b/resolve/main/mmproj-model-f16.gguf?download=true -O mmproj-model-f16.gguf
fi

