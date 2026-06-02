#!/bin/bash

set -ETeuo pipefail

cd pytorch
source $(dirname $0)/util/common.sh

if [[ ! -d "vision" ]]; then
    source $(dirname $0)/../util/git.sh
    do_clone vision https://github.com/pytorch/vision.git v0.24.0
fi

cd vision
python -m pip install -v --no-build-isolation --no-deps -e .
