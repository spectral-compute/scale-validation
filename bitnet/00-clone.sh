#!/bin/bash

set -ETeuo pipefail
source "$(dirname "$0")"/../util/args.sh "$@"

mkdir -p "${OUT_DIR}/bitnet"
cd "${OUT_DIR}/bitnet"

do_clone_hash bitnet https://github.com/microsoft/BitNet.git "$(get_version bitnet)"
