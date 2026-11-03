#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh

# The *-pdlp-no-presolve tests match the objective to 7-8 digits, which only NVIDIA's arithmetic
# reproduces: PDLP is a first-order method, so reordered floating-point reductions change its
# iteration count and the digits it stops at (upstream keeps a separate list of digits per
# platform). 03-test-pdlp-instances.sh runs them with a tolerance instead.
STATUS=0
ctest --test-dir build --output-on-failure -E 'pdlp-no-presolve$|^unit_tests_all$' || STATUS=1

# This is upstream's unit_tests_all, run directly (without --success, which ctest would hide) to
# filter it. The unit tests take ~20s, but upstream gives them a 10000s timeout, which overrides
# ctest's --timeout: bound a hang ourselves.
# SCALE doesn't record ROCm-library calls in a stream capture, so HiPDLP's captured graph runs its
# cuBLAS/cuSPARSE work at capture time rather than at replay, and hi-pdlp diverges and never
# terminates.
UNIT_TESTS=()
if [[ -n "${SCALE_ENV:-}" ]]; then
    UNIT_TESTS+=('~hi-pdlp')
fi
(cd build/check && timeout 600 ../bin/unit_tests "${UNIT_TESTS[@]}") || STATUS=1

exit "${STATUS}"
