#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh
raise_error_if_using_rocm

ulimit -s unlimited

./build/bonsai2_slowdust -i build/model3_child_compact.tipsy -T 1
