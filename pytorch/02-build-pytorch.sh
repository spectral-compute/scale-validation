#!/bin/bash
set -ETeuo pipefail
SCRIPT_DIR="$(dirname "$(realpath $0)")"

cd pytorch
source "$SCRIPT_DIR/util/common.sh"

python setup.py build
python setup.py install --skip-build
