#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh

do_clone alien https://github.com/chrxh/alien.git "$(get_version alien)"
