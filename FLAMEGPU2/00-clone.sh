#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh
raise_error_if_using_rocm

do_clone FLAMEGPU2 https://github.com/FLAMEGPU/FLAMEGPU2.git "$(get_version FLAMEGPU2)"
