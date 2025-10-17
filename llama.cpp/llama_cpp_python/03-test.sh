#!/bin/bash

set -ETeuo pipefail
SCRIPT_DIR="$(realpath "$(dirname "$0")")"
source "${SCRIPT_DIR}"/../../util/args.sh "$@"
source "${SCALE_DIR}/bin/scaleenv" gfx1100

source ${OUT_DIR}/llama-cpp-python/llama_cpp_python_scale_venv/bin/activate

cd ${OUT_DIR}/llama-cpp-python/llama-cpp-python

pip install pytest
pip install scipy
pip install huggingface_hub

PYTHONPATH=. python -m pytest

