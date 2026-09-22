#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh
raise_error_if_using_rocm

do_clone GPUJPEG https://github.com/CESNET/GPUJPEG "$(get_version GPUJPEG)"
