#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh
raise_error_if_using_rocm

do_clone heraclespp https://github.com/Maison-de-la-Simulation/heraclespp.git "$(get_version heraclespp)"
