#!/bin/bash

set -e
source "$(dirname "$0")"/../util/args.sh "$@"

mkdir -p "${OUT_DIR}/nvflip"
cd "${OUT_DIR}/nvflip"

do_clone_hash nvflip https://github.com/NVlabs/flip.git "$(cat "$(dirname $0)/version.txt" | grep "nvflip" | sed "s/nvflip //g")"
