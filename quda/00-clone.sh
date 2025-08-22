#!/bin/bash

set -ETeuo pipefail
source "$(dirname "$0")"/../util/args.sh "$@"

mkdir -p "${OUT_DIR}/quda"
cd "${OUT_DIR}/quda"

do_clone_hash quda https://github.com/lattice/quda.git 07822b61c6ab5fa9586233b03ac794bf33ab647e
