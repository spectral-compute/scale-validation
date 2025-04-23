#!/bin/bash

set -ETeuo pipefail
SCRIPT_DIR="$(realpath "$(dirname "$0")")"
source "${SCRIPT_DIR}"/../util/args.sh "$@"

cd "${OUT_DIR}/quda/quda"

# Libstdc++ has become more strict about includes.
for F in $(grep 'std::exchange' -rn | sed -E 's/:.*//' | sort -u) ; do
    sed '1s/^/#include <utility>\n/' -i "${F}"
done
