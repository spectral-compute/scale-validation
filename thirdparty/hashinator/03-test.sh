#!/bin/bash

set -ETeuo pipefail
SCRIPT_DIR="$(realpath "$(dirname "$0")")"
source "${SCRIPT_DIR}"/../util/args.sh "$@"

cd "${OUT_DIR}/hashinator/hashinator"
export LD_LIBRARY_PATH="${CUDA_DIR}/lib"

# Test.
meson test -C build
