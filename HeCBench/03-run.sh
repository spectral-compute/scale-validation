#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh

SRC_DIR="$(realpath .)/HeCBench"
RESULTS_DIR="${RESULTS_DIR:-/tmp/ci_benchmarks}"
mkdir -p "$RESULTS_DIR"

if [[ "$TEST_TOOLCHAIN" == "scale" ]]; then
    scaleinfo_bin="$(command -v scaleinfo || echo "$TOOLKIT_DIR/bin/scaleinfo")"
    if [[ ! -x "$scaleinfo_bin" ]]; then
        echo "Error: Cannot find scaleinfo for this scale run." 1>&2
        exit 1
    fi
    "$scaleinfo_bin" >"$RESULTS_DIR/scale_info.txt"
else
    lspci 2>/dev/null | grep -i 'vga\|display' >"$RESULTS_DIR/pci_info.txt" || true
fi

case "${TEST_MODE}" in
scale-amd | scale-nvidia) preset="scale-cuda-sm${CUDAARCHS#sm_}" ;;
nvcc-nvidia) preset="cuda-sm${CUDAARCHS#sm_}" ;;
hip-amd)
    : "${HIP_VISIBLE_DEVICES:?required to be set}"
    preset="hip-${TEST_GPU_ARCH}"
    ;;
*)
    echo "Unrecognised test mode: $TEST_MODE" 1>&2
    exit 1
    ;;
esac


tag="${preset#scale-}"
stem="$TEST_TOOLCHAIN.$TEST_GPU_ARCH.$tag"
data_file="$RESULTS_DIR/hecbench.$stem.$(date '+%Y%m%d-%H%M%S').csv"

python3 "$SRC_DIR/tools/hecbench" run \
    --model "${tag%%-*}" \
    --preset "$preset" \
    --store "hecbench-results.$stem.db" \
    --format csv \
    --output "$data_file"

if [ "$(wc -l <"$data_file")" -le 1 ]; then
    echo "hecbench produced no results (every benchmark skipped)" >&2
    exit 1
fi
