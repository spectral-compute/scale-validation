#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh

# TODO(#1144): Kill.
#
# Pytorch tries to use and other GPUs leading to errors.
export CUDA_VISIBLE_DEVICES="${CUDA_VISIBLE_DEVICES:-0}"

cd pytorch
source .venv/bin/activate

SCRIPT_DIR="$(dirname "$(realpath "$0")")"

# If this is exported, pytorch requires installing `.ci/docker/requirements-ci.txt`, which is not
# necessary to run the tests, and seems rather huge, so vetting that everything it installs is
# things that we don't need to think about is a mild pain, for now.
unset CI

mapfile -t TESTS < <(cat "$SCRIPT_DIR/util/cuda-tests.txt" | sort)
python -u test/test_torch.py -v "${TESTS[@]}"
