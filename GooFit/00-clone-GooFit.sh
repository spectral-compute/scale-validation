#!/bin/bash

set -e
source "$(dirname "$0")"/../util/args.sh "$@"

mkdir -p "${OUT_DIR}/GooFit"
cd "${OUT_DIR}/GooFit"

do_clone GooFit https://github.com/GooFit/GooFit.git "$(get_version GooFit)"
