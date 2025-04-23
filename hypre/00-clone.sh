#!/bin/bash

set -ETeuo pipefail
source "$(dirname "$0")"/../util/args.sh "$@"

mkdir -p "${OUT_DIR}/hypre"
cd "${OUT_DIR}/hypre"

do_clone_hash hypre https://github.com/hypre-space/hypre.git 57bfb26e268ddf003668c5d0b5938ae258922a83
