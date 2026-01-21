#!/bin/bash

set -ETeuo pipefail

SCRIPT_DIR="$(realpath "$(dirname "$0")")"

cd "FLAMEGPU2"

for P in "${SCRIPT_DIR}"/*.patch ; do
    patch -p0 < "${P}"
done

cd -
