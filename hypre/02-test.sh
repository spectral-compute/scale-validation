#!/bin/bash

set -ETeuo pipefail

cd "build/src/test"

for T in bench error fac gpumemcheck ij lobpcg longdouble single sstruct struct superlu timing ; do
    ./runtest.sh -t TEST_${T}/*.sh
done
