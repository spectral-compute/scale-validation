#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh

# GMXRC doesn't like the strict error flags we use in our scripts
set +ETeuo pipefail
source "install/bin/GMXRC"
set -ETeuo pipefail

make -O -C build tests -j
ctest --test-dir build --verbose 2>&1 | tee "regression-test.txt"
