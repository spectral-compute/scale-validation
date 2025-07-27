#!/bin/bash

set -ETeuo pipefail
source "$(dirname "$0")"/../util/args.sh "$@"

mkdir -p "${OUT_DIR}/cuSZ"
cd "${OUT_DIR}/cuSZ"

do_clone cuSZ https://github.com/szcompressor/cuSZ.git v0.6
