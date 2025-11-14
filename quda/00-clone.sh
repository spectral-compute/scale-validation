#!/bin/bash

set -ETeuo pipefail
source "$(dirname "$0")"/../util/args.sh "$@"

mkdir -p "${OUT_DIR}/quda"
cd "${OUT_DIR}/quda"

do_clone_hash quda https://github.com/lattice/quda.git "$(cat "$(dirname $0)/version.txt" | grep "quda" | sed "s/quda //g")"
