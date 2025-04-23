#!/bin/bash

set -ETeuo pipefail
SCRIPT_DIR="$(realpath "$(dirname "$0")")"
source "${SCRIPT_DIR}"/../util/args.sh "$@"

export LD_LIBRARY_PATH="${CUDA_PATH}/lib"

cd "${OUT_DIR}/gomc/GOMC_Examples/NVT_GEMC/pure_fluid/octane_T_360_00_K"
git clean -df .
"${OUT_DIR}/gomc/build/GOMC_GPU_GEMC" in.conf 2>&1 | tee test.log

if grep -F 'Warning: Updated energy differs from Recalculated Energy!' test.log ; then
    echo "Error: Result is incorrect."
    exit 1
fi
