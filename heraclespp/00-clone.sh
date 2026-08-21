#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh

do_clone heraclespp https://github.com/Maison-de-la-Simulation/heraclespp.git "$(get_version heraclespp)"
