#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh

source "$SCRIPT_DIR/../util/git.sh"
cd pytorch
do_clone vision https://github.com/pytorch/vision.git v0.24.0

# TODO(#1156): Are any of these env vars required/useful for torchvision?
source "$SCRIPT_DIR/util/build-env.sh"

source .venv/bin/activate
cd vision
python -m pip install -v --no-build-isolation -e .
