#!/bin/bash

set -ETeuo pipefail
source "$(dirname "$0")"/../util/args.sh "$@"

mkdir -p "${OUT_DIR}/gpu_jpeg2k"
cd "${OUT_DIR}/gpu_jpeg2k"

do_clone_hash gpu_jpeg2k https://github.com/ePirat/gpu_jpeg2k "$(cat "$(dirname $0)/version.txt" | grep "gpu_jpeg2k" | sed "s/gpu_jpeg2k //g")"
