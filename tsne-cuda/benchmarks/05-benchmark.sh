#!/usr/bin/env bash
# shellcheck source-path=SCRIPTDIR
. "$(dirname "$0")"/../../util/prelude.sh

# Times t-SNE (1000 iterations) of synthetic clustered datasets: wall time, plus tsne-cuda's own
# per-phase timers (seconds).
OUT="${RESULTS_DIR:-$(realpath .)}/tsne-cuda.${BENCHMARK_COMPILER:-unknown}.${TEST_GPU_ARCH}.$(date -u +%Y%m%d%H%M%S).csv"
PYTHONPATH="${PWD}/build/python" python3 "${SCRIPT_DIR}/bench.py" >"${OUT}"
cat "${OUT}"
[[ "$(wc -l <"${OUT}")" -gt 1 ]]
