#!/bin/bash

set -ETeuo pipefail
source "$(dirname "$0")"/../util/args.sh "$@"
cd "${OUT_DIR}/FLAMEGPU2/build"

export LD_LIBRARY_PATH="${CUDA_PATH}/lib"
export FLAMEGPU_INC_DIR="${OUT_DIR}/FLAMEGPU2/FLAMEGPU2/include"

# Err why is this needed only in CI?
export CUDA_PATH="${CUDA_PATH}"

./bin/Release/tests --gtest_filter='-LoggingTest.CUDAEnsembleSimulate:DependencyGraphTest.UnattachedFunctionWarning'
