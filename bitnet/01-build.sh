#!/bin/bash

SCRIPT_DIR="$(realpath "$(dirname "$0")")"
source "${SCRIPT_DIR}"/../util/args.sh "$@"

cd "${OUT_DIR}/bitnet/bitnet/gpu"

cd bitnet_kernels
bash compile.sh
cd ..
