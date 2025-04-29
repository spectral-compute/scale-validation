#!/bin/bash

set -ETeuo pipefail
#source "$(dirname "$0")"/../util/args.sh "$@"

# Could seperate this later but just build and run together for simplicity
OUT_DIR="$(realpath "$1")"
BUILD_JOBS=$(nproc)
cmake \
    -DCMAKE_BUILD_TYPE=Release \
    -DLLAMA_CUBLAS=ON \
    -DCMAKE_INSTALL_PREFIX="${OUT_DIR}/llama.cpp/install-cuda" \
    -B"${OUT_DIR}/llama.cpp/build-cuda" \
    "${OUT_DIR}/llama.cpp/llama.cpp"
make -C "${OUT_DIR}/llama.cpp/build-cuda" install -j"${BUILD_JOBS}"

cd "${OUT_DIR}/llama.cpp/install-cuda/bin"
./llava-cli -m "${OUT_DIR}/llama.cpp/models/ggml-model-q5_k.gguf" --mmproj "${OUT_DIR}/llama.cpp/models/mmproj-model-f16.gguf" --image "${OUT_DIR}/llama.cpp/house.jpg" -p "describe the image in detail. In English" --temp 0.1 -ngl 99    

