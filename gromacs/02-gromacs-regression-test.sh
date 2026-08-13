#!/bin/bash

set -eo pipefail

source "$BIN_INSTALL_PATH/bin/GMXRC"

make -O -C build tests -j
ctest --test-dir build --verbose 2>&1 | tee "regression-test.txt"
