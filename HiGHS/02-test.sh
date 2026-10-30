#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh

# The *-pdlp-no-presolve tests match the objective to 7-8 digits, which only NVIDIA's arithmetic
# reproduces: PDLP is a first-order method, so reordered floating-point reductions change its
# iteration count and the digits it stops at (upstream keeps a separate list of digits per
# platform). 03-test-pdlp-instances.sh runs them with a tolerance instead.
STATUS=0
ctest --test-dir build --output-on-failure -E 'pdlp-no-presolve$|^unit_tests_all$' || STATUS=1

# The unit tests take ~20s, but upstream gives them a 10000s timeout, which overrides ctest's
# --timeout. Bound a hang ourselves.
timeout 600 ctest --test-dir build --output-on-failure -R '^unit_tests_all$' || STATUS=1

exit "${STATUS}"
