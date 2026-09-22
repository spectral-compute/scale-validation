#!/bin/bash

set -eo pipefail

# Only test_pair_style carries a TEST(PairStyle, gpu) fixture. These are MolPairStyle:,
# AtomicPairStyle:, ManybodyPairStyle: and KSpaceStyle:
ctest --test-dir build --verbose --output-on-failure \
    -R '^(MolPairStyle|AtomicPairStyle|ManybodyPairStyle|KSpaceStyle):'
