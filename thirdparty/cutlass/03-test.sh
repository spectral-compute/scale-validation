#!/bin/bash

set -ETeuo pipefail
SCRIPT_DIR="$(realpath "$(dirname "$0")")"
source "${SCRIPT_DIR}"/../util/args.sh "$@"

cd "${OUT_DIR}/cutlass/build"
export LD_LIBRARY_PATH="${CUDA_DIR}/lib"
make test_unit -j
