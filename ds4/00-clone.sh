#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh

do_clone ds4 https://github.com/antirez/ds4.git "$(get_version ds4)"
