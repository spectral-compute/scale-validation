#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh

# The Allocator.OOM test segfaults even with an nvcc/nvidia build.
# The *Death tests are testing for correct operation in the presence of process crashes,
# which we do not properly support due to bugs in the AMD linux kernel driver.

FILTER="-Allocator.OOM:*Death*:LambdaRank.GPUMakePair:AllgatherTest.Basic:Objective.GPUAFTObjGPairLeftCensoredLabels:Objective.GPUAFTObjGPairRightCensoredLabels:Objective.GPUAFTObjGPairIntervalCensoredLabels"

# SketchBatchNumElements expects an element count that xgboost clamps to INT32_MAX once more than
# ~50 GB is free (as on an MI210), whatever the platform.
# AllreduceTest.Restricted is a host-only socket test that fails in our containers.
FILTER="${FILTER}:HistUtil.SketchBatchNumElements:AllreduceTest.Restricted"

# DMatrixCache.MultiThread starts 128 threads per hardware_concurrency() (65k on a 512-core box), ignoring cpusets.
FILTER="${FILTER}:DMatrixCache.MultiThread"

if [[ "${SCALE_ENV:-}" == "gfx1201" ]]; then
    # EllpackPage fails on gfx1201, tracked here: https://code.spectralcompute.com/spectral-compute/scale/issues/722#issuecomment-14135
    FILTER="${FILTER}:EllpackPage.*"
fi

# OpenMP pools scale with visible CPUs (thousands of threads at 512): cap at 16.
CPUS="$(python3 -c 'import os; print(",".join(map(str, sorted(os.sched_getaffinity(0))[:16])))')"

taskset -c "${CPUS}" ./build/testxgboost --gtest_output=xml:xgboost.xml --gtest_filter="$FILTER"
