#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh

do_clone timemachine https://github.com/proteneer/timemachine.git "$(get_version timemachine)"
