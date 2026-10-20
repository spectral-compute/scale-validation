# Shared setup for the SGLang benchmarks. Source from the test workdir.

source .venv/bin/activate

RESULTS_DIR="${RESULTS_DIR:-/tmp/ci_benchmarks}"
mkdir -p "${RESULTS_DIR}"

# Small enough for a 16GB card. Dummy weights: performance doesn't depend on
# them, and only the config and tokenizer get downloaded.
SGLANG_BENCH_MODEL="${SGLANG_BENCH_MODEL:-Qwen/Qwen2.5-1.5B-Instruct}"
bench_args=(--model-path "${SGLANG_BENCH_MODEL}" --load-format dummy)

if [[ "${BENCHMARK_COMPILER:-}" == "hip" ]]; then
    # aiter's kernels are CDNA-only, and SGLang defaults to them on ROCm (as
    # upstream's RDNA image notes).
    if [[ "${TEST_GPU_ARCH}" == gfx1* ]]; then
        export SGLANG_USE_AITER=0
        bench_args+=(--attention-backend triton)
    fi
else
    # The same attention kernels for SCALE and nvcc. SGLang defaults to FA3 on
    # Hopper and TRT-LLM's prebuilt kernels on Blackwell, which the SCALE build
    # lacks; elsewhere FlashInfer is its default anyway.
    bench_args+=(--attention-backend flashinfer)
fi

# Extra server arguments, e.g. SGLANG_BENCH_ARGS="--attention-backend flashinfer".
read -ra extra_args <<<"${SGLANG_BENCH_ARGS:-}"
bench_args+=("${extra_args[@]}")

# One file per toolchain, arch and repeat, as benchmark.py's -n runs share a
# RESULTS_DIR.
results_file() {
    echo "${RESULTS_DIR}/sglang-$1.${BENCHMARK_COMPILER:-scale}.${TEST_GPU_ARCH}.$(date '+%Y%m%d-%H%M%S').r${BENCHMARK_REPEAT:-1}.jsonl"
}

# Fail if a benchmark wrote nothing, rather than "pass" with no data.
check_results() {
    if [[ ! -s "$1" ]]; then
        log "No results in $1"
        exit 1
    fi
}
