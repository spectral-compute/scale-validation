#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh
raise_error_if_using_rocm

do_clone nixl https://github.com/ai-dynamo/nixl.git "$(get_version nixl)"
do_clone ucx https://github.com/openucx/ucx.git "$(get_version ucx)"
