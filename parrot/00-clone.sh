#!/bin/bash

set -e
source "$(dirname "$0")"/../util/args.sh "$@"

mkdir -p "${OUT_DIR}/parrot"
cd "${OUT_DIR}/parrot"

do_clone_hash parrot https://github.com/NVlabs/parrot.git c88d995
