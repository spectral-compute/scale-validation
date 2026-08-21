#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh

for P in "${SCRIPT_DIR}"/*.patch; do
    git -C Bonsai apply "${P}"
done
