#!/bin/bash

set -e
source "$(dirname "$0")"/../util/args.sh "$@"

# We have to copy so the late stages of setup.py build work.
rm -rf "${OUT_DIR}/pytorch/build"
cp -r --reflink=auto "${OUT_DIR}/pytorch/pytorch" "${OUT_DIR}/pytorch/build"
cd "${OUT_DIR}/pytorch/build"

# (This also makes patching easier)
