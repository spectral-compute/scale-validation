#!/bin/bash

set -e
source "$(dirname "$0")"/../util/args.sh "$@"

cd "${OUT_DIR}/openmpi"

cd "build"

make -sk -j$(nproc) install
