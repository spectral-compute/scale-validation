#!/bin/bash

set -e
SCRIPT_DIR="$(realpath "$(dirname "$0")")"
source "${SCRIPT_DIR}"/../util/args.sh "$@"

for P in "${SCRIPT_DIR}/"*.patch ; do
    patch --ignore-whitespace -p0 -d "${OUT_DIR}/GooFit/GooFit" < "${P}"
done
