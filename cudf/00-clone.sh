#!/bin/bash

set -ETeuo pipefail
source "$(dirname "$0")"/../util/args.sh "$@"

mkdir -p "${OUT_DIR}/cudf"
cd "${OUT_DIR}/cudf"

do_clone cudf https://github.com/rapidsai/cudf v25.06.00
