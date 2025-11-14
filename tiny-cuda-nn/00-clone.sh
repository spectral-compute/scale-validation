#!/bin/bash

set -ETeuo pipefail
source "$(dirname "$0")"/../util/args.sh "$@"
SCRIPT_DIR="$(realpath "$(dirname "$0")")"

mkdir -p "${OUT_DIR}/tiny-cuda-nn"
cd "${OUT_DIR}/tiny-cuda-nn"

do_clone tiny-cuda-nn https://github.com/NVlabs/tiny-cuda-nn "$(cat "$(dirname $0)/version.txt" | grep "tiny-cuda-nn" | sed "s/tiny-cuda-nn //g")"

cd "${OUT_DIR}/tiny-cuda-nn/tiny-cuda-nn"
# Patch that disables jit fusion to alow the use of cutlass.
# Also adds CutlassMLP in nn configuration file and reduces
# the number of iterations to avoid huge executions.
git apply "${SCRIPT_DIR}/enable_cutlass.patch"
