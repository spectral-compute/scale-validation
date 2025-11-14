#!/bin/bash

set -ETeuo pipefail
source "$(dirname "$0")"/../util/args.sh "$@"

mkdir -p "${OUT_DIR}/cugraph"
cd "${OUT_DIR}/cugraph"

do_clone_hash cugraph https://github.com/rapidsai/cugraph "$(cat "$(dirname $0)/version.txt" | grep "cugraph" | sed "s/cugraph //g")"
