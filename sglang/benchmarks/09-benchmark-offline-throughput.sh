#!/usr/bin/env bash
# shellcheck source-path=SCRIPTDIR
. "$(dirname "$0")"/../../util/prelude.sh
source "${SCRIPT_DIR}/util/bench-env.sh"

# Throughput of the full engine (scheduler, batching, CUDA graphs), without a
# server. Random prompts of fixed lengths (their tokens are sampled from
# ShareGPT, downloaded once).
out="$(results_file offline-throughput)"
python -m sglang.benchmark.offline_throughput "${bench_args[@]}" \
    --dataset-name random \
    --random-range-ratio 1.0 \
    --num-prompts 500 \
    --random-input-len 512 \
    --random-output-len 128 \
    --seed 42 \
    --result-filename "${out}"
check_results "${out}"
