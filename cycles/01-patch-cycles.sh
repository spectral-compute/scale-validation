#!/bin/bash

set -e
SCRIPT_DIR="$(realpath "$(dirname "$0")")"
source "${SCRIPT_DIR}"/../util/args.sh "$@"

# Patch cycles
# glog.patch: Fixes a compilation issue caused by upstream cycles being incompatible
#             with very new versions of glog
# intrinsics.patch: Fix a misuse of `ifndef(HIP)` that breaks CUDA
for P in glog intrinsics; do
    patch -p0 -d "${OUT_DIR}/cycles/cycles" < "${SCRIPT_DIR}/${P}.patch"
done
