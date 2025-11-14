#!/bin/bash

set -e
source "$(dirname "$0")"/../util/args.sh "$@"

mkdir -p "${OUT_DIR}/AMGX"
cd "${OUT_DIR}/AMGX"

do_clone AMGX https://github.com/NVIDIA/AMGX.git "$(cat "$(dirname $0)/version.txt" | grep "AMGX" | sed "s/AMGX //g")"
