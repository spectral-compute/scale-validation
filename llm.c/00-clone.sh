#!/bin/bash

set -ETeuo pipefail

source "$(dirname "$0")"/../util/git.sh

# llm.c doesn't do tags, releases, or release branches, it seems.
do_clone_hash llm.c https://github.com/karpathy/llm.c.git "$(get_version llm.c)"
