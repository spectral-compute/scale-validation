#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh
raise_error_if_using_rocm

do_clone hashinator https://github.com/kstppd/hashinator.git "$(get_version hashinator)"
