#!/usr/bin/env bash
# shellcheck source-path=SCRIPTDIR
. "$(dirname "$0")"/../../util/prelude.sh

# What PyTorch's dynamo benchmarks need, at the versions its CI pins (triton for inductor).
cd pytorch
source .venv/bin/activate
python -m pip install -r .ci/docker/ci_commit_pins/huggingface-requirements.txt \
    "triton==$(cat .ci/docker/triton_version.txt)" accelerate pandas psutil scipy tabulate tqdm
