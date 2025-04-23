#!/bin/bash

set -e
source "$(dirname "$0")"/../util/args.sh "$@"

mkdir -p "${OUT_DIR}/risc0"
cd "${OUT_DIR}/risc0"

do_clone risc0 https://github.com/risc0/risc0.git v1.2.2
