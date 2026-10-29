#!/usr/bin/env bash
# shellcheck source-path=SCRIPTDIR
. "$(dirname "$0")"/../../util/prelude.sh

ROCM_VERSION="$(cut -d . -f 1-2 "${ROCM_PATH}/.info/version")"
TORCHVISION_VERSION="$(get_version sglang-torchvision | sed -e 's|^v||')"

source .venv/bin/activate
python -m pip install --index-url "https://download.pytorch.org/whl/rocm${ROCM_VERSION}" \
    --no-deps "torchvision==${TORCHVISION_VERSION}"
