#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh
raise_error_if_using_rocm

do_clone gpu_jpeg2k https://github.com/ePirat/gpu_jpeg2k "$(get_version gpu_jpeg2k)"
