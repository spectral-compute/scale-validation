#!/bin/bash

set -e
source "$(dirname "$0")"/../util/args.sh "$@"

mkdir -p "${OUT_DIR}/risc0"
cd "${OUT_DIR}/risc0"

do_clone risc0 https://github.com/risc0/risc0.git "$(cat "$(dirname $0)/version.txt" | grep "risc0" | sed "s/risc0 //g")"
