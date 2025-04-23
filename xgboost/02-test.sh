#!/bin/bash

set -e
source "$(dirname "$0")"/../util/args.sh "$@"
cd "${OUT_DIR}/xgboost/build"

# The Allocator.OOM test segfaults even with an nvcc/nvidia build.
# The *Death tests are testing for correct operation in the presence of process crashes,
# which we do not properly support due to bugs in the AMD linux kernel driver.
./testxgboost --gtest_output=xml:xgboost.xml --gtest_filter="-Allocator.OOM:*Death*:LambdaRank.GPUMakePair:AllgatherTest.Basic:Objective.GPUAFTObjGPairLeftCensoredLabels:Objective.GPUAFTObjGPairRightCensoredLabels:Objective.GPUAFTObjGPairIntervalCensoredLabels"
