#!/bin/bash

set -e

source "install/bin/GMXRC"

OUT="$(pwd)/regression-test.txt"

set +e

make -C build tests -j
ctest --test-dir build 2>&1 | tee "${OUT}"
