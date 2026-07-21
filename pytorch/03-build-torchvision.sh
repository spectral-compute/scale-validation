#!/bin/bash
set -ETeuo pipefail
SCRIPT_DIR="$(dirname "$(realpath $0)")"

cd pytorch
source "$SCRIPT_DIR/util/common.sh"

source "$SCRIPT_DIR/../util/git.sh"
do_clone vision https://github.com/pytorch/vision.git v0.24.0

cd vision
python -m pip install -v --no-build-isolation --no-deps -e .
