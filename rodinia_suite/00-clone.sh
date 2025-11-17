#!/bin/bash

set -ETeuo pipefail
source "$(dirname "$0")"/../util/args.sh "$@"

mkdir -p "${OUT_DIR}/rodinia_suite"
cd "${OUT_DIR}/rodinia_suite"

do_clone rodinia_suite https://github.com/manospavlidakis/rodinia_suite.git "$(get_version rodinia_suite)"
