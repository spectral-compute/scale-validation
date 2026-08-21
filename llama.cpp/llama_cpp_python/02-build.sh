#!/usr/bin/env bash
. "$(dirname "$0")"/../../util/prelude.sh

python3 -m venv "${OUT_DIR}/llama-cpp-python/llama_cpp_python_scale_venv"
source "${OUT_DIR}/llama-cpp-python/llama_cpp_python_scale_venv/bin/activate"

CMAKE_ARGS="-DGGML_CUDA=on" pip install "${OUT_DIR}/llama-cpp-python/llama-cpp-python" --no-cache-dir --force-reinstall
