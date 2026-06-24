#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(realpath "$(dirname "$0")")"

for P in "${SCRIPT_DIR}"/*.patch ; do
    git -C Bonsai apply "${P}"
done
