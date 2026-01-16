#!/bin/bash

set -e
source "$(dirname "$0")"/../util/args.sh "$@"

mkdir -p "${OUT_DIR}/pytorch_2.9.0"
cd "${OUT_DIR}/pytorch_2.9.0"
do_clone pytorch_2.9.0 https://github.com/pytorch/pytorch.git v2.9.0-rc4
