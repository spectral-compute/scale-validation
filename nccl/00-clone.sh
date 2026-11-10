#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh

do_clone nccl https://github.com/NVIDIA/nccl.git "$(get_version nccl)"
do_clone nccl-tests https://github.com/NVIDIA/nccl-tests.git "$(get_version nccl-tests)"
