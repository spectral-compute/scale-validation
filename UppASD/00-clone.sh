#!/bin/bash

set -e
source "$(dirname "$0")"/../util/args.sh "$@"

mkdir -p "${OUT_DIR}/UppASD"
cd "${OUT_DIR}/UppASD"

do_clone UppASD https://github.com/UppASD/UppASD.git gpu_new

