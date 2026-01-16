#!/bin/bash

set -e
source "$(dirname "$0")"/../util/args.sh "$@"

# We have to copy so the late stages of setup.py build work.
rm -rf "${OUT_DIR}/pytorch_2.9.0/build"
cp -r --reflink=auto "${OUT_DIR}/pytorch_2.9.0/pytorch_2.9.0" "${OUT_DIR}/pytorch_2.9.0/build"
cd "${OUT_DIR}/pytorch_2.9.0/build"
