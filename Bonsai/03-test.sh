#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh

ulimit -s unlimited

./build/bonsai2_slowdust -i build/model3_child_compact.tipsy -T 1
