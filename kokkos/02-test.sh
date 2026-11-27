#!/usr/bin/env bash
# shellcheck disable=2329
. "$(dirname "$0")"/../util/prelude.sh
. "$(dirname "$0")"/../util/checks.sh

# The *TimingBased tests compare kernel run times of well under a
# millisecond, so they flake when other tests share the GPU. Run them on
# their own, after everything else.
run_parallel() {
    ctest --test-dir build/ --parallel 8 --verbose -E TimingBased
}
run_timing() {
    ctest --test-dir build/ --verbose -R TimingBased
}
check "tests in parallel" run_parallel
check "timing-based tests, serially" run_timing
check_exit
