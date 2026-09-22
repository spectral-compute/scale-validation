#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh
raise_error_if_using_rocm

do_clone quda https://github.com/lattice/quda.git "$(get_version quda)"
