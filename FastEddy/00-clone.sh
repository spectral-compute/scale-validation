#!/bin/bash

set -e
source "$(dirname "$0")"/../util/args.sh "$@"

mkdir -p "${OUT_DIR}/FastEddy"
cd "${OUT_DIR}/FastEddy"

do_clone FastEddy https://github.com/NCAR/FastEddy-model.git v3.0.0
