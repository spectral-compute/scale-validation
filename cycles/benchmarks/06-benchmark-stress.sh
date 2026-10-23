#!/usr/bin/env bash
# shellcheck source-path=SCRIPTDIR disable=2329
. "$(dirname "$0")"/../../util/prelude.sh

source "$SCALE_VALIDATION/util/checks.sh"

# Comparing renders needs ImageMagick's compare, plus python3.
for TOOL in compare python3; do
    if ! command -v "${TOOL}" >/dev/null; then
        log "${TOOL} not found (install imagemagick/python3)"
        exit 1
    fi
done

# Stress GPU rendering: many back-to-back renders of one scene, each of which
# must match the first (catches hangs, crashes and corruption that only show
# up under sustained load), then one large, long-running render.
ITERS="${CYCLES_STRESS_ITERS:-20}"
TIMEOUT="${CYCLES_STRESS_TIMEOUT:-900}"
LARGE_SAMPLES="${CYCLES_STRESS_LARGE_SAMPLES:-1024}"
LARGE_WIDTH="${CYCLES_STRESS_LARGE_WIDTH:-3840}"
LARGE_HEIGHT="${CYCLES_STRESS_LARGE_HEIGHT:-2160}"

# SCALE (AMD or NVIDIA) and nvcc builds render through Cycles's CUDA backend;
# the native ROCm build (benchmarks/02-build-hip.sh) through its HIP backend.
DEVICE=CUDA
if [[ "${BENCHMARK_COMPILER:-}" == "hip" ]]; then
    DEVICE=HIP
fi

RESULTS_DIR="${RESULTS_DIR:-/tmp/ci_benchmarks}"
mkdir -p "$RESULTS_DIR"

stem="${BENCHMARK_COMPILER:-${DEVICE,,}}.$TEST_GPU_ARCH.r${BENCHMARK_REPEAT:-1}"
data_file="$RESULTS_DIR/cycles-stress.$stem.$(date '+%Y%m%d-%H%M%S').csv"
echo "render,seconds" >"$data_file"

# render <name> <scene> [cycles args...]: timed GPU render to ./stress_<name>.png
render() {
    local name="$1"
    local scene="$2"
    shift 2
    local start
    local secs
    start="$(date +%s.%N)"
    timeout "${TIMEOUT}" ./install/cycles "./cycles/examples/scene_${scene}.xml" \
        --device "${DEVICE}" --background --quiet \
        --output "./stress_${name}.png" "$@" || return 1
    secs="$(awk "BEGIN { printf \"%.3f\", $(date +%s.%N) - ${start} }")"
    log "${name}: ${secs}s"
    echo "${name},${secs}" >>"$data_file"
}

# Same device, scene and seed, so renders should be near-identical.
matches_reference() {
    local mse
    mse="$(compare -metric mse ./stress_ref.png "$1" /dev/null 2>&1 | head -n 1 | cut -f 1 -d ' ')"
    log "MSE vs first render: ${mse}"
    [ "$(echo "print(${mse} < 0.0001)" | python3)" == "True" ]
}

sustained_render() {
    render "iter$1" monkey --samples 256 &&
        matches_reference "./stress_iter$1.png"
}

large_render() {
    render large cube_volume \
        --samples "${LARGE_SAMPLES}" \
        --width "${LARGE_WIDTH}" --height "${LARGE_HEIGHT}" &&
        [ -s ./stress_large.png ]
}

render ref monkey --samples 256
for ((I = 1; I <= ITERS; I++)); do
    check "sustained render ${I}/${ITERS} matches first" sustained_render "${I}"
done
check "large render (${LARGE_WIDTH}x${LARGE_HEIGHT}, ${LARGE_SAMPLES} samples)" large_render

check_exit
