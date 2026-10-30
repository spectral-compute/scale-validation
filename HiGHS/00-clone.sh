#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh

do_clone HiGHS https://github.com/ERGO-Code/HiGHS.git "$(get_version HiGHS)"
