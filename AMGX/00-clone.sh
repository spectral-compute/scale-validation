#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh
raise_error_if_using_rocm

do_clone AMGX https://github.com/NVIDIA/AMGX.git "$(get_version AMGX)"
