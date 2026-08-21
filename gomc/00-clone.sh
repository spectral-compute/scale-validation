#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh

do_clone GOMC https://github.com/GOMC-WSU/GOMC.git "$(get_version gomc)"
do_clone GOMC_Examples https://github.com/GOMC-WSU/GOMC_Examples.git "$(get_version GOMC_Examples)"
