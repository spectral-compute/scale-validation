#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh
raise_error_if_using_rocm

# llm.c doesn't do tags, releases, or release branches, it seems.
do_clone llm.c https://github.com/karpathy/llm.c.git "$(get_version llm.c)"
