#!/bin/bash

set -ETeuo pipefail
SCRIPT_DIR="$(realpath "$(dirname "$0")")"
source "${SCRIPT_DIR}"/../util/args.sh "$@"

# Configure.
cd "${OUT_DIR}/hashinator/hashinator"
mkdir subprojects
meson wrap install gtest
meson setup -Dwerror=false build --buildtype=release
meson compile -C build --jobs=8
