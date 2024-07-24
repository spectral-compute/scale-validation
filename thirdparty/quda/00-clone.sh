#!/bin/bash

set -ETeuo pipefail
source "$(dirname "$0")"/../util/args.sh "$@"

mkdir -p "${OUT_DIR}/quda"
cd "${OUT_DIR}/quda"

do_clone quda https://github.com/lattice/quda.git b87195b38416648885c1d602dd6395b9a60ee269
