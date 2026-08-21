#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh

do_clone warp https://github.com/NVIDIA/warp.git "$(get_version warp)"
