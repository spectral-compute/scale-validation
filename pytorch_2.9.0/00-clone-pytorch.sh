#!/bin/bash

set -e
source "$(dirname "$0")"/../util/args.sh "$@"

mkdir -p "${OUT_DIR}/pytorch"
cd "${OUT_DIR}/pytorch"
do_clone pytorch https://github.com/pytorch/pytorch.git v2.9.0-rc4
