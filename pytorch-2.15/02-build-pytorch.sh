#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh

# The pytorch project's build, through pip: PyTorch 2.15 builds with scikit-build-core, and its setup.py no longer
# builds. -k 0 goes to Ninja, as the pytorch project's patch does for its setup.py.
cd pytorch
source "${SCALE_VALIDATION}/pytorch/util/build-env.sh"

python3 -m venv .venv
source .venv/bin/activate
python -m pip install --upgrade pip -r requirements.txt

SKBUILD_BUILD_TOOL_ARGS="-k;0" python -m pip install -v --no-build-isolation .
