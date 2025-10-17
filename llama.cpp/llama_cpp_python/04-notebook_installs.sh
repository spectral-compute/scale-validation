#!/bin/bash

set -ETeuo pipefail
SCRIPT_DIR="$(realpath "$(dirname "$0")")"
source "${SCRIPT_DIR}"/../../util/args.sh "$@"
source "${SCALE_DIR}/bin/scaleenv" gfx1100

source ${OUT_DIR}/llama-cpp-python/llama_cpp_python_scale_venv/bin/activate

pip install ipykernel
pip install jupyter-lab

python -m ipykernel install --user --name=my-project-venv --display-name="Python 3 (My Project)"

pip install matplotlib ipympl

