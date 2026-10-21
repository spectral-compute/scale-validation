#!/usr/bin/env bash
# shellcheck disable=2329
. "$(dirname "$0")"/../util/prelude.sh
source "$SCALE_VALIDATION/util/checks.sh"

# SGLang's kernel correctness tests: each checks one kernel (AOT sgl-kernel,
# JIT-compiled or Triton) against a reference implementation. These are the
# single-GPU suites from its CI; "large" means an H100-sized GPU, and most tests
# for features an architecture lacks skip themselves.
source .venv/bin/activate
source "${SCRIPT_DIR}/util/kernel-cache.sh"
cd sglang/test

check_small() {
    python run_suite.py --hw cuda --suite base-b-kernel-unit-test-1-gpu-small --continue-on-error
}

check_large() {
    python run_suite.py --hw cuda --suite base-b-kernel-unit-test-1-gpu-large --continue-on-error
}

check "kernel unit tests (1-gpu-small)" check_small
check "kernel unit tests (1-gpu-large)" check_large
check_exit
