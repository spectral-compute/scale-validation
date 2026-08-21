#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh

# llm.c doesn't do tags, releases, or release branches, it seems.
do_clone llm.c https://github.com/karpathy/llm.c.git "$(get_version llm.c)"
