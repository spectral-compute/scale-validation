#!/bin/bash

set -ETeuo pipefail
source "$(dirname "$0")"/../util/args.sh "$@"

mkdir -p "${OUT_DIR}/jitify"
cd "${OUT_DIR}/jitify"
do_clone jitify git@github.com:NVIDIA/jitify.git master
