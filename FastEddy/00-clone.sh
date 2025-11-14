#!/bin/bash

set -e
source "$(dirname "$0")"/../util/args.sh "$@"

mkdir -p "${OUT_DIR}/FastEddy"
cd "${OUT_DIR}/FastEddy"

do_clone FastEddy https://github.com/NCAR/FastEddy-model.git "$(cat "$(dirname $0)/version.txt" | grep "FastEddy" | sed "s/FastEddy //g")"
