#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh

do_clone nvflip https://github.com/NVlabs/flip.git "$(get_version nvflip)"
