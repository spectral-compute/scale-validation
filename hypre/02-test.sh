#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh

for T in bench error fac gpumemcheck ij lobpcg longdouble single sstruct struct superlu timing; do
    (cd "build/src/test" && ./runtest.sh -t TEST_${T}/*.sh)
done
