#!/usr/bin/env bash
# shellcheck source-path=SCRIPTDIR
. "$(dirname "$0")"/../../util/prelude.sh

# Time GPU renders of the bundled example scenes at a fixed workload, so runs
# are comparable across toolchains. Times are wall-clock per render, so they
# include scene load and device setup as well as the render itself.
SCENES=(cube_surface cube_volume monkey sphere_bump)
SAMPLES="${CYCLES_BENCH_SAMPLES:-512}"
WIDTH="${CYCLES_BENCH_WIDTH:-1920}"
HEIGHT="${CYCLES_BENCH_HEIGHT:-1080}"

# SCALE (AMD or NVIDIA) and nvcc builds render through Cycles's CUDA backend;
# the native ROCm build (benchmarks/02-build-hip.sh) through its HIP backend.
DEVICE=CUDA
if [[ "${BENCHMARK_COMPILER:-}" == "hip" ]]; then
    DEVICE=HIP
fi

RESULTS_DIR="${RESULTS_DIR:-/tmp/ci_benchmarks}"
mkdir -p "$RESULTS_DIR"

stem="${BENCHMARK_COMPILER:-${DEVICE,,}}.$TEST_GPU_ARCH.r${BENCHMARK_REPEAT:-1}"
data_file="$RESULTS_DIR/cycles-render.$stem.$(date '+%Y%m%d-%H%M%S').csv"

echo "scene,samples,width,height,seconds" >"$data_file"
for SCENE in "${SCENES[@]}"; do
    log "Rendering ${SCENE} (${WIDTH}x${HEIGHT}, ${SAMPLES} samples)"
    START="$(date +%s.%N)"
    ./install/cycles "./cycles/examples/scene_${SCENE}.xml" \
        --device "${DEVICE}" --background --quiet \
        --samples "$SAMPLES" --width "$WIDTH" --height "$HEIGHT" \
        --output "./bench_${SCENE}.png"
    SECS="$(awk "BEGIN { printf \"%.3f\", $(date +%s.%N) - ${START} }")"
    log "${SCENE}: ${SECS}s"
    echo "${SCENE},${SAMPLES},${WIDTH},${HEIGHT},${SECS}" >>"$data_file"
done
