#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh
raise_error_if_using_rocm

do_clone risc0 https://github.com/risc0/risc0.git "$(get_version risc0)"
