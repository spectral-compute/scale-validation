#!/bin/bash

set -eo pipefail

# every Kokkos sub-test self-skips in a CUDA build. What still runs is
# the "plain" fixture, which checks that a Kokkos-enabled build computes correct forces at all
# but the actual validation lives in 03-test-examples.sh

# Runs serially, deliberately: every test here shares one GPU
ctest --test-dir build --verbose --output-on-failure \
    -R '^(MolPairStyle|AtomicPairStyle|ManybodyPairStyle|KSpaceStyle):'
