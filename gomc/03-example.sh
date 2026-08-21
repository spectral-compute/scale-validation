#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh

OUT_DIR=$(realpath .)
cd "GOMC_Examples/NVT_GEMC/pure_fluid/octane_T_360_00_K"
git clean -df .
"${OUT_DIR}/build/GOMC_GPU_GEMC" in.conf 2>&1 | tee test.log

if grep -F 'Warning: Updated energy differs from Recalculated Energy!' test.log; then
    log "Error: Result is incorrect."
    exit 1
fi
