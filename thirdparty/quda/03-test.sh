#!/bin/bash

set -ETeuo pipefail
source "$(dirname "$0")"/../util/args.sh "$@"
cd "${OUT_DIR}/quda/install/bin"

export LD_LIBRARY_PATH="${CUDA_DIR}/lib"
for F in $(find . -type f -executable) ; do
    "${F}"
done
