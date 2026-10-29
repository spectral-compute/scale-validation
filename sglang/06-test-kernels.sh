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

# Triton kernels can't run under SCALE (Triton emits NVIDIA binaries): count the
# test cases that fail only for that as expected failures, and list them.
xfail_log="$(realpath .)/triton-expected-failures.jsonl"
rm -f "${xfail_log}"
export PYTHONPATH="${SCRIPT_DIR}/util/python${PYTHONPATH:+:${PYTHONPATH}}"
export PYTEST_PLUGINS=scale_triton_xfail
export SCALE_TRITON_XFAIL_LOG="${xfail_log}"

# FlashInfer's CUDA norms rather than its CuTe DSL ones, which emit NVIDIA binaries.
export FLASHINFER_USE_CUDA_NORM=1

# torch's own Triton (and CuTe DSL) implementations of some ops, which the
# tests' torch reference computations would otherwise use.
export TORCH_DISABLE_NATIVE_JIT=1

cd sglang/test

check_small() {
    python run_suite.py --hw cuda --suite base-b-kernel-unit-test-1-gpu-small --continue-on-error
}

check_large() {
    python run_suite.py --hw cuda --suite base-b-kernel-unit-test-1-gpu-large --continue-on-error
}

check "kernel unit tests (1-gpu-small)" check_small
check "kernel unit tests (1-gpu-large)" check_large

if [[ -s "${xfail_log}" ]]; then
    log "$(wc -l <"${xfail_log}") test cases failed only in Triton, as expected (${xfail_log})"
fi
check_exit
