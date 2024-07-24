#!/bin/bash

set -ETeuo pipefail
source "$(dirname "$0")"/../util/args.sh "$@"

mkdir -p "${OUT_DIR}/llama.cpp"
cd "${OUT_DIR}/llama.cpp"
do_clone llama.cpp https://github.com/ggerganov/llama.cpp b1500

mkdir models
cd models

if [ ! -e llama-2-7b.Q4_0.gguf ] ; then
    wget -q https://huggingface.co/TheBloke/Llama-2-7B-GGUF/resolve/main/llama-2-7b.Q4_0.gguf
fi
