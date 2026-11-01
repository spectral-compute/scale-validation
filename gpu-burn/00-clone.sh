#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh

do_clone gpu-burn https://github.com/wilicc/gpu-burn.git "$(get_version gpu-burn)"
