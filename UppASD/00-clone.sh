#!/bin/bash

set -e
source "$(dirname "$0")"/../util/args.sh "$@"

mkdir -p "${OUT_DIR}/UppASD"
cd "${OUT_DIR}/UppASD"

do_clone UppASD git@github.com:UppASD/UppASD.git "$(get_version UppASD)"
