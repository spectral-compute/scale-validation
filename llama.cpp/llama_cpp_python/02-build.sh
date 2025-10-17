#!/bin/bash

set -ETeuo pipefail
SCRIPT_DIR="$(realpath "$(dirname "$0")")"
source "${SCRIPT_DIR}"/../../util/args.sh "$@"
source "${SCALE_DIR}/bin/scaleenv" gfx1100

python3 -m venv "${OUT_DIR}/llama-cpp-python/llama_cpp_python_scale_venv"
source ${OUT_DIR}/llama-cpp-python/llama_cpp_python_scale_venv/bin/activate

CMAKE_ARGS="-DGGML_CUDA=on" pip install ${OUT_DIR}/llama-cpp-python/llama-cpp-python --no-cache-dir --force-reinstall
