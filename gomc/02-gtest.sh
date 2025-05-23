#!/bin/bash

set -e
source "$(dirname "$0")"/../util/args.sh "$@"
cd "${OUT_DIR}/gomc/build"

echo "Testsuites are (report artifact set needs to match):"
echo GOMC_GPU_*_Test

for F in GOMC_GPU_*_Test ; do
    echo "Running test $F"
    ./"${F}" --gtest_output=xml:$F.xml --gtest_filter="-ConsistentTrajectoryTest.*"
done
