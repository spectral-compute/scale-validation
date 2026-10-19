#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh

do_clone sglang https://github.com/sgl-project/sglang.git "$(get_version sglang)"

# SGLang pins an exact torch, newer than the pytorch test's, so this test
# builds its own rather than sharing that venv.
do_clone pytorch https://github.com/pytorch/pytorch.git "$(get_version sglang-pytorch)"
do_clone vision https://github.com/pytorch/vision.git "$(get_version sglang-torchvision)"
