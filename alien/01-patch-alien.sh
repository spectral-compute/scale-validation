#!/bin/bash

set -e
SCRIPT_DIR="$(realpath "$(dirname "$0")")"

# Make Ninja quiet
# This way there is no build log spam
git -C alien apply "${SCRIPT_DIR}/patches/0001-remove-dyn-parallelism.patch"
