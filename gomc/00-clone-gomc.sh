#!/bin/bash

set -e
source "$(dirname "$0")"/../util/args.sh "$@"

mkdir -p "${OUT_DIR}/gomc"
cd "${OUT_DIR}/gomc"

do_clone_hash GOMC https://github.com/GOMC-WSU/GOMC.git "$(cat "$(dirname $0)/version.txt" | grep "GOMC" | sed "s/GOMC //g")"
do_clone_hash GOMC_Examples https://github.com/GOMC-WSU/GOMC_Examples.git "$(cat "$(dirname $0)/version.txt" | grep "GOMC_Examples" | sed "s/GOMC_Examples //g")"
