#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh

do_clone FLAMEGPU2 https://github.com/FLAMEGPU/FLAMEGPU2.git "$(get_version FLAMEGPU2)"
