#!/bin/bash

set -ETeuo pipefail
SCRIPT_DIR="$(realpath "$(dirname "$0")")"
source "${SCRIPT_DIR}"/../util/args.sh "$@"

cd "${OUT_DIR}/thrust/build"
export LD_LIBRARY_PATH="${CUDA_DIR}/lib"
ctest --output-on-failure --output-junit thrust.xml -E "thrust.test.complex_transform|thrust.test.sequence|thrust.test.cuda.pair_sort_by_key.cdp_0|thrust.test.cuda.sort_by_key.cdp_0"
