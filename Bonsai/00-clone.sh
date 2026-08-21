#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh

do_clone Bonsai https://github.com/treecode/Bonsai.git "$(get_version Bonsai)"
