#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh

do_clone vllm https://github.com/vllm-project/vllm.git "$(get_version vllm)"
