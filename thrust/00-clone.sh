#!/bin/bash

set -ETeuo pipefail
source "$(dirname "$0")"/../util/args.sh "$@"

mkdir -p "${OUT_DIR}/thrust"
cd "${OUT_DIR}/thrust"

do_clone_hash thrust https://github.com/NVIDIA/thrust.git "$(cat "$(dirname $0)/version.txt" | grep "thrust" | sed "s/thrust //g")"
