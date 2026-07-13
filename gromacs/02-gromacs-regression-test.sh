#!/bin/bash

set -eo pipefail

source "install/bin/GMXRC"

OUT="$(pwd)/regression-test.txt"

make -O -C build tests -j
ctest --test-dir build 2>&1 | tee "${OUT}"
