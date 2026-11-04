#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh

set -eo pipefail

# Each style's kokkos_gpu sub-test checks its Kokkos version against the reference forces on the GPU
# (styles without one self-skip), and the "plain" fixture checks that a Kokkos-enabled build computes
# correct forces at all. The rest of the validation lives in 03-test-examples.sh

# Runs serially, deliberately: every test here shares one GPU
ctest --test-dir build --verbose --output-on-failure \
    -R '^(MolPairStyle|AtomicPairStyle|ManybodyPairStyle|KSpaceStyle):'
