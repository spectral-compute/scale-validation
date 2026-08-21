#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh

do_clone tiny-cuda-nn https://github.com/NVlabs/tiny-cuda-nn "$(get_version tiny-cuda-nn)"
