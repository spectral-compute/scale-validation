#!/bin/bash

set -e
source "$(dirname "$0")"/../util/args.sh "$@"

mkdir -p "${OUT_DIR}/arrayfire"
cd "${OUT_DIR}/arrayfire"

do_clone arrayfire https://github.com/arrayfire/arrayfire.git "$(cat "$(dirname $0)/version.txt" | grep "arrayfire" | sed "s/arrayfire //g")"
