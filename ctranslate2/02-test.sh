#!/bin/bash

set -ETeuo pipefail
source "$(dirname "$0")"/../util/args.sh "$@"

cd "${OUT_DIR}/ctranslate2/ctranslate2/build"
./tests/ctranslate2_test ../tests/data --gtest_filter="CUDA*:-CUDA/OpDeviceTest.QuantizeINT8/0:CUDA/OpDeviceFPTest.Conv1DGroupNoBias/float32:CUDA/OpDeviceFPTest.Conv1DGroupNoBias/float16:CUDA/OpDeviceFPTest.Conv1DGroupNoBias/bfloat16:CUDA/OpDeviceFPTest.Conv1DGroup/float32:CUDA/OpDeviceFPTest.Conv1DGroup/float16:CUDA/OpDeviceFPTest.Conv1DGroup/bfloat16:CUDA/PrimitiveTest.LogSumExp/0"
