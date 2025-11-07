#!/bin/bash
set -ETeuo pipefail
PIN_COMMIT="a7222a000edb9c2a4eb3dc5f97d2472785fa38c2" # Latest commit in master validated (there is no tags)
source "$(dirname "$0")"/../util/args.sh "$@"
rm -rf "${OUT_DIR}/scaling-elections" "${OUT_DIR}/ScalingElections"
mkdir -p "${OUT_DIR}/scaling-elections"
cd "${OUT_DIR}/scaling-elections"

do_clone_hash ScalingElections https://github.com/ashvardanian/ScalingElections.git "${PIN_COMMIT}"