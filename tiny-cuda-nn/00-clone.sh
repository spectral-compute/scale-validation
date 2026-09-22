#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh
raise_error_if_using_rocm

do_clone tiny-cuda-nn https://github.com/NVlabs/tiny-cuda-nn "$(get_version tiny-cuda-nn)"
