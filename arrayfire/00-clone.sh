#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh
raise_error_if_using_rocm

do_clone arrayfire https://github.com/arrayfire/arrayfire.git "$(get_version arrayfire)"
