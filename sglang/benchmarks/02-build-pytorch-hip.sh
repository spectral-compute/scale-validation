#!/usr/bin/env bash
# shellcheck source-path=SCRIPTDIR
. "$(dirname "$0")"/../../util/prelude.sh

if ! python3 -c 'import sys; sys.exit(sys.version_info < (3, 11))'; then
    log "SGLang needs Python >= 3.11, but python3 is $(python3 --version)"
    exit 1
fi

# AMD's wheels, for the ROCm release installed (e.g. rocm7.2).
ROCM_VERSION="$(cut -d . -f 1-2 "${ROCM_PATH}/.info/version")"
TORCH_VERSION="$(get_version sglang-pytorch | sed -e 's|^v||')"

python3 -m venv .venv
source .venv/bin/activate
python -m pip install --upgrade pip
python -m pip install --index-url "https://download.pytorch.org/whl/rocm${ROCM_VERSION}" \
    "torch==${TORCH_VERSION}"

python -c 'import torch; assert torch.version.hip, "not a ROCm torch"'
