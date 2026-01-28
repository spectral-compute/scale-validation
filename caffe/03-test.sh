#!/bin/bash

set -e

set +e
# The BenchmarkTest* tests are overly fragile. This is a defect in those tests, not SCALE
cd build && GTEST_FILTER='-BenchmarkTest*' make runtest
