#!/bin/bash

set -ETeuo pipefail
source "$(dirname "$0")"/../util/args.sh "$@"

mkdir -p "${OUT_DIR}/cuml"
cd "${OUT_DIR}/cuml"

do_clone_hash cuml https://github.com/rapidsai/cuml.git "$(cat "$(dirname $0)/version.txt" | grep "cuml" | sed "s/cuml //g")"
