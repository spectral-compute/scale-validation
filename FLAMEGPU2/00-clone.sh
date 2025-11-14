#!/bin/bash

set -ETeuo pipefail
source "$(dirname "$0")"/../util/args.sh "$@"

mkdir -p "${OUT_DIR}/FLAMEGPU2"
cd "${OUT_DIR}/FLAMEGPU2"

do_clone FLAMEGPU2 https://github.com/FLAMEGPU/FLAMEGPU2.git "$(cat "$(dirname $0)/version.txt" | grep "FLAMEGPU2" | sed "s/FLAMEGPU2 //g")"
