#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh
raise_error_if_using_rocm

do_clone colmap https://github.com/colmap/colmap "$(get_version colmap)"
