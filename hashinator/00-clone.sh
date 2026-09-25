#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh

do_clone hashinator https://github.com/kstppd/hashinator.git "$(get_version hashinator)"
