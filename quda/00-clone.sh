#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh

do_clone quda https://github.com/lattice/quda.git "$(get_version quda)"
