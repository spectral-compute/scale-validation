#!/bin/bash

set -ETeuo pipefail
source "$(dirname "$0")"/../util/args.sh "$@"

mkdir -p "${OUT_DIR}/llm.c"
cd "${OUT_DIR}/llm.c"

# llm.c doesn't do tags, releases, or release branches, it seems.
do_clone_hash llm.c https://github.com/karpathy/llm.c.git 7ecd8906afe6ed7a2b2cdb731c042f26d525b820
