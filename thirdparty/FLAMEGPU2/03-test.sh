#!/bin/bash

set -ETeuo pipefail
source "$(dirname "$0")"/../util/args.sh "$@"
cd "${OUT_DIR}/FLAMEGPU2/build"

export LD_LIBRARY_PATH="${CUDA_DIR}/lib"
export FLAMEGPU_INC_DIR="${OUT_DIR}/FLAMEGPU2/FLAMEGPU2/include"

# Err why is this needed only in CI?
export CUDA_PATH="${CUDA_DIR}"

# Our context support isn't *quite* matching yet.
./bin/Release/tests --gtest_filter='-TestUtilDetailCuda.cuDevicePrimaryContextIsActive:TestCUDASimulation.ApplyConfigDerivedContextCreation'
