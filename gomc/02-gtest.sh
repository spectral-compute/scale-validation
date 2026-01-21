#!/bin/bash

set -e

echo "Testsuites are (report artifact set needs to match):"
echo build/GOMC_GPU_*_Test

for F in build/GOMC_GPU_*_Test ; do
    echo "Running test $F"
    ./"${F}" --gtest_output=xml:$F.xml --gtest_filter="-ConsistentTrajectoryTest.*"
done
