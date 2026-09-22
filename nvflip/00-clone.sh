#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh
raise_error_if_using_rocm

do_clone nvflip https://github.com/NVlabs/flip.git "$(get_version nvflip)"
