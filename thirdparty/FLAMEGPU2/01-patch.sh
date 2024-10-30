#!/bin/bash

set -ETeuo pipefail

SCRIPT_DIR="$(realpath "$(dirname "$0")")"
source "${SCRIPT_DIR}"/../util/args.sh "$@"

cd "${OUT_DIR}/FLAMEGPU2/FLAMEGPU2"

for P in "${SCRIPT_DIR}"/*.patch ; do
    patch -p0 < "${P}"
done
