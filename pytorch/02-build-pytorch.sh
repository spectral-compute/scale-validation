#!/bin/bash
set -ETeuo pipefail
SCRIPT_DIR="$(dirname "$(realpath $0)")"

cd pytorch
source "$SCRIPT_DIR/util/build-env.sh"

python3 -m venv .venv
source .venv/bin/activate
python -m pip install --upgrade pip -r requirements.txt

python setup.py build
python setup.py install --skip-build
