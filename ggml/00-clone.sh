#!/bin/bash

set -ETeuo pipefail
source "$(dirname "$0")"/../util/args.sh "$@"

mkdir -p "${OUT_DIR}/ggml"
cd "${OUT_DIR}/ggml"
do_clone_hash ggml https://github.com/ggml-org/ggml "$(get_version ggml)"
