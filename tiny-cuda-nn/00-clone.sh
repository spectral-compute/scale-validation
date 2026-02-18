#!/bin/bash

set -ETeuo pipefail

source "$(dirname "$0")"/../util/git.sh

do_clone tiny-cuda-nn https://github.com/NVlabs/tiny-cuda-nn "$(get_version tiny-cuda-nn)"

# Patch that disables jit fusion to alow the use of cutlass.
# Also adds CutlassMLP in nn configuration file and reduces
# the number of iterations to avoid huge executions.
SCRIPT_DIR="$(realpath "$(dirname "$0")")"
git -C tiny-cuda-nn apply "${SCRIPT_DIR}/enable_cutlass.patch"
