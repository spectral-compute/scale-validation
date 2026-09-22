#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh
raise_error_if_using_rocm

do_clone pytorch https://github.com/pytorch/pytorch.git "$(get_version pytorch)"
