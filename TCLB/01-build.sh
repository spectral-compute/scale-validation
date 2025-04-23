#!/bin/bash

set -ETeuo pipefail

SCRIPT_DIR="$(realpath "$(dirname "$0")")"
source "${SCRIPT_DIR}"/../util/args.sh "$@"

cd "${OUT_DIR}/TCLB/TCLB"
tools/install.sh rdep
make configure
./configure --with-cuda-arch="$(echo "${GPU_ARCH}" | sed -E 's/^sm_//')"
make d2q9 -j$(nproc)
