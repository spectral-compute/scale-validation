#!/usr/bin/env bash
# shellcheck source-path=SCRIPTDIR
. "$(dirname "$0")"/../../util/prelude.sh

cd HeCBench

PRESET="scale-hip-$TEST_GPU_ARCH"
RESULTS_DIR="${RESULTS_DIR:-/tmp/ci_benchmarks}"
mkdir -p "$RESULTS_DIR"

stem="hip.$TEST_GPU_ARCH"
data_file="$RESULTS_DIR/hecbench.$stem.$(date '+%Y%m%d-%H%M%S').csv"

# Optional: a space-separated subset of benchmark names, without the model
# suffix (default: all).
read -ra BENCHES <<<"${HECBENCH_BENCHMARKS:-}"
BENCHES=("${BENCHES[@]/%/-hip}")
python3 tools/hecbench run \
    "${BENCHES[@]}" \
    --model hip \
    --preset "$PRESET" \
    --store "hecbench-results.$stem.db" \
    --format csv \
    --timeout "${HECBENCH_TIMEOUT:-600}" \
    --output "$data_file"
