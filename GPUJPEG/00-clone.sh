#!/bin/bash

set -e
source "$(dirname "$0")"/../util/args.sh "$@"

mkdir -p "${OUT_DIR}/GPUJPEG"
cd "${OUT_DIR}/GPUJPEG"

do_clone_hash GPUJPEG https://github.com/CESNET/GPUJPEG "$(cat "$(dirname $0)/version.txt" | grep "GPUJPEG" | sed "s/GPUJPEG //g")"
