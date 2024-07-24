#!/bin/bash

set -e
source "$(dirname "$0")"/../util/args.sh "$@"
cd "${OUT_DIR}/AMGX/AMGX/build"

export LD_LIBRARY_PATH="${CUDA_DIR}/lib"
ls "${LD_LIBRARY_PATH}"

./src/amgx_tests_launcher

