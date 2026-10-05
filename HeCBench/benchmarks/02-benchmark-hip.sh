#!/usr/bin/env bash
# shellcheck source-path=SCRIPTDIR
. "$(dirname "$0")"/../../util/prelude.sh

cd HeCBench

PRESET="hip-$TEST_GPU_ARCH"
RESULTS_DIR="${RESULTS_DIR:-/tmp/ci_benchmarks}"
mkdir -p "$RESULTS_DIR"

stem="hip.$TEST_GPU_ARCH"
data_file="$RESULTS_DIR/hecbench.$stem.$(date '+%Y%m%d-%H%M%S').csv"

python3 tools/hecbench run \
    --model hip \
    --preset "$PRESET" \
    --store "hecbench-results.$stem.db" \
    --format csv \
    --output "$data_file"
