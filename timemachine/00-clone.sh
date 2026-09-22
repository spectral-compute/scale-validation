#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh
raise_error_if_using_rocm

do_clone timemachine https://github.com/proteneer/timemachine.git "$(get_version timemachine)"
