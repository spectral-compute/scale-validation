#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh
raise_error_if_using_rocm

do_clone Bonsai https://github.com/treecode/Bonsai.git "$(get_version Bonsai)"
