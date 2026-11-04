#!/usr/bin/env bash
# shellcheck source-path=SCRIPTDIR
. "$(dirname "$0")"/../../util/prelude.sh

cd HeCBench

PRESET="scale-hip-$TEST_GPU_ARCH"
RESULTS_DIR="${RESULTS_DIR:-/tmp/ci_benchmarks}"
mkdir -p "$RESULTS_DIR"

stem="hip.$TEST_GPU_ARCH"
data_file="$RESULTS_DIR/hecbench.$stem.$(date '+%Y%m%d-%H%M%S').csv"

# No --store: the DB would land in the per-project workdir, which is wiped each
# run. The CSV in $RESULTS_DIR is the record for now.
python3 tools/hecbench run \
    --model hip \
    --preset "$PRESET" \
    --format csv \
    --output "$data_file"

if [[ "$(wc -l <"$data_file")" -le 1 ]]; then
    log "hecbench produced no results (every benchmark skipped)"
    exit 1
fi
