#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh

# Patch that disables jit fusion to alow the use of cutlass.
# Also adds CutlassMLP in nn configuration file and reduces
# the number of iterations to avoid huge executions.
SCRIPT_DIR="$(realpath "$(dirname "$0")")"
git -C tiny-cuda-nn apply "${SCRIPT_DIR}/enable_cutlass.patch"
