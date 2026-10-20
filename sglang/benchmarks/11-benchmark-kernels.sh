#!/usr/bin/env bash
# shellcheck source-path=SCRIPTDIR
. "$(dirname "$0")"/../../util/prelude.sh
source "${SCRIPT_DIR}/util/bench-env.sh"

# Per-kernel timings from SGLang's kernel benchmark suite (triton.testing's
# do_bench, timed with CUDA events): the most direct comparison of the code each
# toolchain generates. Each file prints its table; keep the lot. Files that fail
# (kernels a toolchain can't build or run) are reported, not fatal.
# ROCm builds have their own suite, of kernels that build there; compare the
# files both suites share.
if [[ "${BENCHMARK_COMPILER:-}" == "hip" ]]; then
    suite=(--hw amd --suite jit-kernel-benchmark-test-amd)
else
    suite=(--hw cuda --suite base-b-kernel-benchmark-test-1-gpu-large)
fi

out="$(results_file kernels | sed -e 's|\.jsonl$|.log|')"
cd sglang/test
python run_suite.py "${suite[@]}" --continue-on-error 2>&1 | tee "${out}" || true
check_results "${out}"
