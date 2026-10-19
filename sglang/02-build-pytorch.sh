#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh

if ! python3 -c 'import sys; sys.exit(sys.version_info < (3, 11))'; then
    log "SGLang needs Python >= 3.11, but python3 is $(python3 --version)"
    exit 1
fi

source "${SCALE_VALIDATION}/pytorch/util/build-env.sh"

# NVIDIA-only libraries that the pytorch test's torch predates.
export USE_CUDSS=OFF
export USE_MSLK=OFF

# Report the release version rather than 2.14.1a0+git<sha>, so that SGLang's
# exact torch pins accept this build.
PYTORCH_BUILD_VERSION="$(get_version sglang-pytorch | sed -e 's|^v||')"
export PYTORCH_BUILD_VERSION
export PYTORCH_BUILD_NUMBER=1

python3 -m venv .venv
source .venv/bin/activate
python -m pip install --upgrade pip
python -m pip install -r pytorch/requirements-build.txt

# torch 2.14 builds with scikit-build-core; `setup.py build` no longer exists.
python -m pip install --no-build-isolation -v ./pytorch
