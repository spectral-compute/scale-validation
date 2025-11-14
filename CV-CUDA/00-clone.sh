#!/bin/bash

set -ETeuo pipefail
source "$(dirname "$0")"/../util/args.sh "$@"

mkdir -p "${OUT_DIR}/CV-CUDA"
cd "${OUT_DIR}/CV-CUDA"

do_clone_hash CV-CUDA https://github.com/CVCUDA/CV-CUDA.git "$(cat "$(dirname $0)/version.txt" | grep "CV-CUDA" | sed "s/CV-CUDA //g")"
