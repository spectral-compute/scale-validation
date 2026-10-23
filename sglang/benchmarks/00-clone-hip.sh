#!/usr/bin/env bash
# shellcheck source-path=SCRIPTDIR
. "$(dirname "$0")"/../../util/prelude.sh

# The native ROCm stack: AMD's torch wheels instead of a source build, plus
# aiter, which SGLang imports unconditionally on ROCm.
do_clone sglang https://github.com/sgl-project/sglang.git "$(get_version sglang)"
do_clone aiter https://github.com/ROCm/aiter.git "$(get_version sglang-aiter)"
