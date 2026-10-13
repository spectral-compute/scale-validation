#!/usr/bin/env bash
# shellcheck source-path=SCRIPTDIR
. "$(dirname "$0")"/../../util/prelude.sh

cd HeCBench

PRESET="scale-cuda-sm${CUDAARCHS#sm_}"
RESULTS_DIR="${RESULTS_DIR:-/tmp/ci_benchmarks}"
mkdir -p "$RESULTS_DIR"

# test.sh doesn't export its mode; SCALE_ENV is set by scaleenv.
if [[ -n "${SCALE_ENV:-}" ]]; then
    mode="scale"
else
    mode="nvidia-cuda"
fi

# Record what hardware the results came from. scaleenv doesn't put scaleinfo on PATH
# for every target (e.g. sm_* only gets llvm/bin), so it's best-effort, not required.
if command -v scaleinfo >/dev/null 2>&1; then
    scaleinfo >"$RESULTS_DIR/scale_info.txt" || true
elif command -v nvidia-smi >/dev/null 2>&1; then
    nvidia-smi >"$RESULTS_DIR/gpu_info.txt" || true
else
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
