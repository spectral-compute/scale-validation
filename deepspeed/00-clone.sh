#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh

do_clone DeepSpeed https://github.com/deepspeedai/DeepSpeed.git "$(get_version deepspeed)"
