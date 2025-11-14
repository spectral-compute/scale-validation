#!/bin/bash

set -ETeuo pipefail
source "$(dirname "$0")"/../util/args.sh "$@"

mkdir -p "${OUT_DIR}/rodinia_suite"
cd "${OUT_DIR}/rodinia_suite"

do_clone rodinia_suite https://github.com/manospavlidakis/rodinia_suite.git "$(cat "$(dirname $0)/version.txt" | grep "rodinia_suite" | sed "s/rodinia_suite //g")"
