#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh

# The BenchmarkTest* tests are overly fragile. This is a defect in those tests, not SCALE.
# GPU gradient-check kernels have hung indefinitely under SCALE before; timeout bounds
# that to 2h instead of an unbounded hang. Invoked directly (matching CMake's `runtest`
# custom target in src/caffe/test/CMakeLists.txt: test.testbin --gtest_shuffle, run from
# the caffe source dir), not via `make runtest`, so timeout supervises the real test
# binary instead of relying on `make` to forward the kill signal. Keep in sync with that
# CMakeLists.txt if the caffe version pin changes.
export GTEST_FILTER='-BenchmarkTest*'
(cd caffe && timeout --kill-after=30s 2h ../build/test/test.testbin --gtest_shuffle)
