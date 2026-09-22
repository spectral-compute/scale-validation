#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh
raise_error_if_using_rocm

do_clone TCLB https://github.com/CFD-GO/TCLB.git "$(get_version TCLB)"
