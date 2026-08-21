#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh

do_clone TCLB https://github.com/CFD-GO/TCLB.git "$(get_version TCLB)"
