#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh

# Skip faulty benchmarks; insert hangs on gfx1201. See scale#385.
# --benchmark_filter is a single regex, so join with '|', not gtest's ':'. The leading '-' negates it.
SKIP=(
    "stdgpu_unordered_.*_insert/.*"
    "stdgpu_unordered_.*_erase/.*"
    "stdgpu_unordered_.*_clear/.*"
)

./build/bin/benchmarkstdgpu --benchmark_filter="-$(
    IFS='|'
    echo "${SKIP[*]}"
)" --benchmark_out_format=csv --benchmark_out=out.csv --v=3
