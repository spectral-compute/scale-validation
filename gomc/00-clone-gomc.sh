#!/bin/bash

set -e
source "$(dirname "$0")"/../util/args.sh "$@"

mkdir -p "${OUT_DIR}/gomc"
cd "${OUT_DIR}/gomc"

do_clone_hash GOMC https://github.com/GOMC-WSU/GOMC.git v2.75a
do_clone_hash GOMC_Examples https://github.com/GOMC-WSU/GOMC_Examples.git v2.75
