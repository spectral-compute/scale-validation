#!/bin/bash

set -e
SCRIPT_DIR="$(realpath "$(dirname "$0")")"

for P in "${SCRIPT_DIR}/"*.patch ; do
    patch --ignore-whitespace -p0 -d "GooFit" < "${P}"
done
