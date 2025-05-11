#!/bin/bash

set -ETeuo pipefail
source "$(dirname "$0")"/../util/args.sh "$@"
cd "${OUT_DIR}/FLAMEGPU2/build"

export LD_LIBRARY_PATH="${CUDA_PATH}/lib"
export FLAMEGPU_INC_DIR="${OUT_DIR}/FLAMEGPU2/FLAMEGPU2/include"

# Err why is this needed only in CI?
export CUDA_PATH="${CUDA_PATH}"

FILTERS='-LoggingTest.CUDAEnsembleSimulate:DependencyGraphTest.UnattachedFunctionWarning'

# On gfx9xx, a bug in the AQL queue implementation causes intermittent deadlocks when multiple
# compute queues are used. Sighhhh.
# These tests are testing for actual speedups from using stream concurrency for kernels, which is
# disabled in SCALE on affected AMD architectures until we finish migrating away from AQL to
# something that works (but is, regrettably, undocumented).
if [[ "$SCALE_ENV" == gfx9* ]]; then
  FILTERS="$FILTERS:TestCUDASimulationConcurrency*"
fi

./bin/Release/tests --gtest_filter=$FILTERS
