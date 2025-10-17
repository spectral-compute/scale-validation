#!/bin/bash

set -ETeuo pipefail
source "$(dirname "$0")"/../../util/args.sh "$@"

cd "${OUT_DIR}/llama-cpp-python"
mkdir -p models
cd models

mkdir -p text_gen/llama
cd text_gen/llama

if [ ! -e llama-2-7b.Q4_0.gguf ] ; then
    wget https://huggingface.co/TheBloke/Llama-2-7B-GGUF/resolve/main/llama-2-7b.Q4_0.gguf
fi

if [ ! -e meta-llama-3-8b-instruct.Q4_K_M.gguf ] ; then
    wget https://huggingface.co/NoelJacob/Meta-Llama-3-8B-Instruct-Q4_K_M-GGUF/resolve/main/meta-llama-3-8b-instruct.Q4_K_M.gguf
fi

if [ ! -e bert-base-uncased-Q8_0.gguf ] ; then
    wget https://huggingface.co/ggml-org/bert-base-uncased/resolve/main/bert-base-uncased-Q8_0.gguf
fi 

cd ../..
mkdir -p multimodal/llava
cd multimodal/llava

if [ ! -e llava-v1.6-mistral-7b.Q4_K_M.gguf ] ; then
    wget https://huggingface.co/cjpais/llava-1.6-mistral-7b-gguf/resolve/main/llava-v1.6-mistral-7b.Q4_K_M.gguf -O llava-v1.6-mistral-7b.Q4_K_M.gguf
fi

if [ ! -e llava-v1.6-mistral-7b-mmproj-model-f16.gguf ] ; then
    wget https://huggingface.co/cjpais/llava-1.6-mistral-7b-gguf/resolve/main/mmproj-model-f16.gguf -O llava-v1.6-mistral-7b-mmproj-model-f16.gguf
fi

