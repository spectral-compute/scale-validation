#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh

cd HeCBench

PRESET="scale-cuda-sm${CUDAARCHS#sm_}"
RESULTS_DIR="${RESULTS_DIR:-/tmp/ci_benchmarks}"
mkdir -p "$RESULTS_DIR"

# test.sh doesn't export its mode; SCALE_ENV is set by scaleenv.
if [[ -n "${SCALE_ENV:-}" ]]; then
    mode="scale"
    scaleinfo >"$RESULTS_DIR/scale_info.txt"
else
    mode="nvidia-cuda"
    lspci 2>/dev/null | grep -i 'vga\|display' >"$RESULTS_DIR/pci_info.txt" || true
fi

stem="$mode.$TEST_GPU_ARCH"
data_file="$RESULTS_DIR/hecbench.$stem.$(date '+%Y%m%d-%H%M%S').csv"

python3 tools/hecbench run \
    --model cuda \
    --preset "$PRESET" \
    --store "hecbench-results.$stem.db" \
    --format csv \
    --output "$data_file"

if [[ "$(wc -l <"$data_file")" -le 1 ]]; then
    log "hecbench produced no results (every benchmark skipped)"
    exit 1
fi
