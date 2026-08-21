#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh

do_clone arrayfire https://github.com/arrayfire/arrayfire.git "$(get_version arrayfire)"
