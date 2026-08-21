#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh

# Make Ninja quiet
# This way there is no build log spam
git -C alien apply "${SCRIPT_DIR}/patches/0001-remove-dyn-parallelism.patch"
