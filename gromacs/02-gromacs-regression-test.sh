#!/bin/bash

set -e
source "$(dirname "$0")"/../util/args.sh "$@"
cd "${OUT_DIR}/gromacs/build"

source "${OUT_DIR}/gromacs/install/bin/GMXRC"

OUT="${OUT_DIR}/gromacs/regression-test.txt"

set +e
make tests -j
ctest 2>&1 | tee "${OUT}"
