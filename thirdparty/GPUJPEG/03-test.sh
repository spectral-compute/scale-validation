#!/bin/bash

set -e
source "$(dirname "$0")"/../util/args.sh "$@"
cd "${OUT_DIR}/GPUJPEG/build"

export LD_LIBRARY_PATH="${CUDA_DIR}/lib"
ctest --verbose
