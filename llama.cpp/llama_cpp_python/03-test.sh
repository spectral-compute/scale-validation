#!/usr/bin/env bash
. "$(dirname "$0")"/../../util/prelude.sh

source "${OUT_DIR}/llama-cpp-python/llama_cpp_python_scale_venv/bin/activate"

cd "${OUT_DIR}/llama-cpp-python/llama-cpp-python"

pip install pytest
pip install scipy
pip install huggingface_hub

PYTHONPATH=. python -m pytest
