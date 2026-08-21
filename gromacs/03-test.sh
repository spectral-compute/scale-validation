#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh

. "install/bin/GMXRC"
make -O -C build tests -j
ctest --test-dir build --verbose 2>&1 | tee "regression-test.txt"
