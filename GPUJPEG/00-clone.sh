#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh

do_clone GPUJPEG https://github.com/CESNET/GPUJPEG "$(get_version GPUJPEG)"
