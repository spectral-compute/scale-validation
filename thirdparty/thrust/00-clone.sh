#!/bin/bash

set -ETeuo pipefail
source "$(dirname "$0")"/../util/args.sh "$@"

mkdir -p "${OUT_DIR}/thrust"
cd "${OUT_DIR}/thrust"

do_clone thrust https://github.com/NVIDIA/thrust.git 756c5af
