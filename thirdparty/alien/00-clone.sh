#!/bin/bash

set -ETeuo pipefail
source "$(dirname "$0")"/../util/args.sh "$@"

mkdir -p "${OUT_DIR}/alien"
cd "${OUT_DIR}/alien"

do_clone alien https://github.com/chrxh/alien.git scaletest
