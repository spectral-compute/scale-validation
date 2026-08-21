#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh

do_clone colmap https://github.com/colmap/colmap "$(get_version colmap)"
