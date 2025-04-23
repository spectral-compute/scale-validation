#!/bin/bash

set -e
source "$(dirname "$0")"/../util/args.sh "$@"

mkdir -p "${OUT_DIR}/MAGMA"
cd "${OUT_DIR}/MAGMA"

do_clone MAGMA https://github.com/icl-utk-edu/magma/ v2.9.0
