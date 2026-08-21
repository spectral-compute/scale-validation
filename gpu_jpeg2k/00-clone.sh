#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh

do_clone gpu_jpeg2k https://github.com/ePirat/gpu_jpeg2k "$(get_version gpu_jpeg2k)"
