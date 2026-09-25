#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh

do_clone MAGMA https://github.com/icl-utk-edu/magma/ "$(get_version MAGMA)"
