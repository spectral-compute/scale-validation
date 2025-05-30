#!/bin/bash

set -ETeuo pipefail
source "$(dirname "$0")"/../util/args.sh "$@"
cd "${OUT_DIR}/hypre/build/src/test"

for T in bench error fac gpumemcheck ij lobpcg longdouble single sstruct struct superlu timing ; do
    ./runtest.sh -t TEST_${T}/*.sh
done
