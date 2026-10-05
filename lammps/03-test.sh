#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh

set -eo pipefail

# Only test_pair_style carries a TEST(PairStyle, gpu) fixture. These are MolPairStyle:,
# AtomicPairStyle:, ManybodyPairStyle: and KSpaceStyle:
# Most PairStyle.gpu runs show SKIPPED, and that's expected: no /gpu variant of the style, or its package isn't built.
# omp/intel/opt/kokkos fixtures skip too, as they're not what this build is for.
ctest --test-dir build --verbose --output-on-failure \
    -R '^(MolPairStyle|AtomicPairStyle|ManybodyPairStyle|KSpaceStyle):'
