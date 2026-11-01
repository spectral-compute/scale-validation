#!/usr/bin/env bash
# shellcheck source-path=SCRIPTDIR
. "$(dirname "$0")"/../../util/prelude.sh

# Simulated seconds per scene: 0.05 s is 10000 steps.
SIM_TIME="${DEME_BENCHMARK_SIM_TIME:-0.05}"
OUT="${RESULTS_DIR:-$(realpath .)}/DEM-Engine.${BENCHMARK_COMPILER:-unknown}.${TEST_GPU_ARCH}.$(date -u +%Y%m%d%H%M%S).csv"

echo "scene,init_s,warmup_s,run_s,steps" >"${OUT}"
BIN="$(realpath build/bin)"
for scene in mixer drum; do
    "${BIN}/DEMBench" "${scene}" "${SIM_TIME}" | tee "${scene}.bench.log"
    sed -nE 's/^BENCH ([a-z]+) init_s=([0-9.e+-]+) warmup_s=([0-9.e+-]+) run_s=([0-9.e+-]+) steps=([0-9]+)$/\1,\2,\3,\4,\5/p' \
        "${scene}.bench.log" >>"${OUT}"
done
cat "${OUT}"
[ "$(wc -l <"${OUT}")" -eq 3 ]
