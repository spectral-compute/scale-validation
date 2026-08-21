#!/usr/bin/env bash
. "$(dirname "$0")"/../../util/prelude.sh

source "${OUT_DIR}/llama-cpp-python/llama_cpp_python_scale_venv/bin/activate"

pip install ipykernel
pip install jupyter-lab

python -m ipykernel install --user --name=my-project-venv --display-name="Python 3 (My Project)"

pip install matplotlib ipympl
