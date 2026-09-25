#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh

do_clone AMGX https://github.com/NVIDIA/AMGX.git "$(get_version AMGX)"
