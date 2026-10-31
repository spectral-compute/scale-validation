#!/usr/bin/env bash
# shellcheck source-path=SCRIPTDIR
. "$(dirname "$0")"/../../util/prelude.sh

source .venv/bin/activate

RESULTS_DIR="${RESULTS_DIR:-$(realpath .)/results}"
mkdir -p "${RESULTS_DIR}"
OUT="${RESULTS_DIR}/ppisp.${BENCHMARK_COMPILER:-unknown}.${TEST_GPU_ARCH:-unknown}.$(date -u +%Y%m%d%H%M%SZ).csv"

python "${SCRIPT_DIR}/bench.py" | tee "${OUT}"
[ "$(wc -l <"${OUT}")" -gt 1 ]
