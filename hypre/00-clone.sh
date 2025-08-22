#!/bin/bash

set -ETeuo pipefail
source "$(dirname "$0")"/../util/args.sh "$@"

mkdir -p "${OUT_DIR}/hypre"
cd "${OUT_DIR}/hypre"

do_clone_hash hypre https://github.com/hypre-space/hypre.git v2.33.0
