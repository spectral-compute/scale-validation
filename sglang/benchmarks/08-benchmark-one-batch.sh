#!/usr/bin/env bash
# shellcheck source-path=SCRIPTDIR
. "$(dirname "$0")"/../../util/prelude.sh
source "${SCRIPT_DIR}/util/bench-env.sh"

# Latency of single static batches, without a server: closest to the kernels.
out="$(results_file one-batch)"
python -m sglang.benchmark.one_batch "${bench_args[@]}" \
    --batch-size 1 8 32 \
    --input-len 512 \
    --output-len 128 \
    --run-name "${BENCHMARK_COMPILER:-scale}.${TEST_GPU_ARCH}" \
    --result-filename "${out}"
check_results "${out}"
