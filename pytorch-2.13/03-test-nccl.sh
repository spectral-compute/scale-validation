#!/usr/bin/env bash
# shellcheck disable=2317,2329
. "$(dirname "$0")"/../util/prelude.sh

source "${SCALE_VALIDATION}/util/checks.sh"

# vllm's tensor parallelism needs torch.distributed's NCCL backend. PyTorch builds with the nccl project of the same
# workdir (pytorch/util/build-env.sh), and without NCCL when that wasn't built first. Needs no GPU.
NCCL_VERSION="$(get_version nccl)"
source pytorch/.venv/bin/activate

check_nccl_available() {
    python -c "import torch.distributed as dist; assert dist.is_nccl_available()"
}

# versions.txt names a release tag (v2.29.7-1); torch reports the NCCL it loaded as (2, 29, 7).
check_nccl_version() {
    python - "${NCCL_VERSION}" <<'PY'
import sys

import torch

want = tuple(int(n) for n in sys.argv[1].lstrip("v").split("-")[0].split("."))
got = torch.cuda.nccl.version()[:3]
assert got == want, f"torch loads NCCL {got}, the nccl project is {want}"
PY
}

check "torch.distributed has NCCL" check_nccl_available
check "torch loads NCCL ${NCCL_VERSION}" check_nccl_version
check_exit
