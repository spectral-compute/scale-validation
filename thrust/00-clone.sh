#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh
raise_error_if_using_rocm

do_clone thrust https://github.com/NVIDIA/thrust.git "$(get_version thrust)"
