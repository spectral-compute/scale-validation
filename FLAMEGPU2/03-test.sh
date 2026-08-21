#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh

# Err why is this needed only in CI?
export CUDA_PATH

FILTERS='-LoggingTest.CUDAEnsembleSimulate:DependencyGraphTest.UnattachedFunctionWarning:*DeathTest*'

# On gfx9xx, a bug in the AQL queue implementation causes intermittent deadlocks when multiple
# compute queues are used. Sighhhh.
# These tests are testing for actual speedups from using stream concurrency for kernels, which is
# disabled in SCALE on affected AMD architectures until we finish migrating away from AQL to
# something that works (but is, regrettably, undocumented).
if [[ "$SCALE_ENV" == gfx9* ]]; then
    FILTERS="$FILTERS:TestCUDASimulationConcurrency*"
fi

FLAMEGPU_INC_DIR="$(pwd)/FLAMEGPU2/include"
export FLAMEGPU_INC_DIR

./build/bin/Release/tests "--gtest_filter=$FILTERS"
