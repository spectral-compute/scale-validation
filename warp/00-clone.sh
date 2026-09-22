#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh
raise_error_if_using_rocm

do_clone warp https://github.com/NVIDIA/warp.git "$(get_version warp)"
