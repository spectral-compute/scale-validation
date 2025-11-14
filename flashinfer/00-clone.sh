#!/bin/bash

set -ETeuo pipefail
source "$(dirname "$0")"/../util/args.sh "$@"

mkdir -p "${OUT_DIR}/flashinfer"
cd "${OUT_DIR}/flashinfer"

do_clone flashinfer https://github.com/flashinfer-ai/flashinfer.git "$(cat "$(dirname $0)/version.txt" | grep "flashinfer" | sed "s/flashinfer //g")"
