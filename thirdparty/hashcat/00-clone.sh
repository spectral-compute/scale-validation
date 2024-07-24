#!/bin/bash

set -e
source "$(dirname "$0")"/../util/args.sh "$@"

mkdir -p "${OUT_DIR}/hashcat"
cd "${OUT_DIR}/hashcat"
do_clone hashcat https://github.com/hashcat/hashcat.git 6716447dfce969ddde42a9abe0681500bee0df48
