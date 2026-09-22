#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh
raise_error_if_using_rocm

do_clone vllm https://github.com/vllm-project/vllm.git "$(get_version vllm)"
