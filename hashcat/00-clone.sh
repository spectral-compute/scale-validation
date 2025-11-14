#!/bin/bash

set -e
source "$(dirname "$0")"/../util/args.sh "$@"

mkdir -p "${OUT_DIR}/hashcat"
cd "${OUT_DIR}/hashcat"

do_clone_hash hashcat https://github.com/hashcat/hashcat.git "$(cat "$(dirname $0)/version.txt" | grep "hashcat" | sed "s/hashcat //g")"
