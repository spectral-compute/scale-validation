#!/bin/bash

set -ETeuo pipefail
source "$(dirname "$0")"/../util/args.sh "$@"

mkdir -p "${OUT_DIR}/bitnet"
cd "${OUT_DIR}/bitnet"

do_clone_hash bitnet https://github.com/microsoft/BitNet.git 404980eecae38affa4871c3e419eae3f44536a95
