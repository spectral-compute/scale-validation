#!/bin/bash

set -e
source "$(dirname "$0")"/../util/args.sh "$@"
SCRIPT_DIR="$(realpath "$(dirname "$0")")"

cd "${OUT_DIR}/pytorch/build"


# Make Ninja quiet
# This way there is no build log spam
git apply "${SCRIPT_DIR}/patches/0001-quiet-ninja.patch"
