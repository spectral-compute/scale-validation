#!/bin/bash

set -ETeuo pipefail
source "$(dirname "$0")"/../util/args.sh "$@"

mkdir -p "${OUT_DIR}/TCLB"
cd "${OUT_DIR}/TCLB"
do_clone TCLB https://github.com/CFD-GO/TCLB.git v6.7
