#!/bin/bash

set -ETeuo pipefail
source "$(dirname "$0")"/../util/args.sh "$@"

mkdir -p "${OUT_DIR}/hashinator"
cd "${OUT_DIR}/hashinator"

do_clone hashinator https://github.com/kstppd/hashinator.git 34cf188
