#!/bin/bash

set -eo pipefail

source "install/bin/GMXRC"

make -O -C build tests -j
ctest --test-dir build 2>&1 | tee "regression-test.txt"
