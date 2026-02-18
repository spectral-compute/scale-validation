#!/bin/bash

set -ETeuo pipefail

SCRIPT_DIR="$(realpath "$(dirname "$0")")"

cd "faiss"

for P in "${SCRIPT_DIR}"/*.patch ; do
    patch -p0 < "${P}"
done

cd -
