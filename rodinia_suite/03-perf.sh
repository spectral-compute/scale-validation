#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh

# Skip by default when test.sh runs all *.sh
if [[ "${RUN_PERF_EVAL:-0}" != "1" ]]; then
    log "[ SKIPPED ] performance evaluation (set RUN_PERF_EVAL=1 to enable)"
    exit 0
fi

usage() {
    cat <<'EOF'
Run Rodinia performance evaluation for SCALE.

Usage:
  RUN_PERF_EVAL=1 ./test.sh WORKDIR SCALE_DIR GPU_ARCH rodinia_suite

Environment variables:
  RUNS=<N>             Number of iterations (default: 2)
  SLEEP_SECS=<secs>    Sleep between iterations (default: 10)
  OUT_DIR=<dir>        Results directory inside cuda/ (default: results)
  GPU_ID=<id>          GPU id for runRodiniaWithIntervals.sh
  LABEL=<str>          Label prefix (default: scale)
EOF
}

case "${1:-}" in
-h | --help)
    usage
    exit 0
    ;;
"") ;;
*)
    echo "ERROR: unknown argument: $1" >&2
    exit 2
    ;;
esac

# Match 02-test.sh path logic
REPO_ROOT="$(pwd)/rodinia_suite"
CUDA_DIR="${REPO_ROOT}/cuda"

RUNS="${RUNS:-5}"
SLEEP_SECS="${SLEEP_SECS:-10}"
OUT_DIR="${OUT_DIR:-results}"
GPU_ID="${GPU_ID:-0}"
LABEL="${LABEL:-scale}"

if [[ ! -d "${CUDA_DIR}" ]]; then
    log "[ ERROR ] Missing directory: ${CUDA_DIR}" >&2
    exit 1
fi

run_in_dir() {
    local dir="$1"
    shift
    (cd "$dir" && "$@")
}

log "[===================]"
log "[ REPO ROOT         ] ${REPO_ROOT}"
log "[ CUDA DIR          ] ${CUDA_DIR}"
log "[ RUNS              ] ${RUNS}"
log "[ SLEEP_SECS        ] ${SLEEP_SECS}"
log "[ OUT_DIR           ] ${OUT_DIR}"
log "[ GPU_ID            ] ${GPU_ID}"
log "[ LABEL             ] ${LABEL}"
log "[===================]"

# 1) Build without breakdowns
log "[ STEP 1 ] Build Rodinia (no breakdowns)"
run_in_dir "${CUDA_DIR}" ./buildall.sh --cuda "${CUDA_PATH}" --sm "${CUDAARCHS}" --no-breakdowns --spectral

# 2) Run without breakdowns
log "[ STEP 2 ] Run Rodinia (no breakdowns)"
run_in_dir "${CUDA_DIR}" env \
    RERUN_APPS=1 DO_BREAKDOWNS=0 LABEL="${LABEL}" OUT_DIR="${OUT_DIR}" \
    RUNS="${RUNS}" SLEEP_SECS="${SLEEP_SECS}" GPU_ID="${GPU_ID}" \
    ./runRodiniaWithIntervals.sh

# 3) Plot computation
log "[ STEP 3 ] Plot computation"
run_in_dir "${REPO_ROOT}" ./run_plot_computation.sh

# 4) Build with breakdowns
log "[ STEP 4 ] Build Rodinia (with breakdowns)"
run_in_dir "${CUDA_DIR}" ./buildall.sh --cuda "${CUDA_PATH}" --sm "${CUDAARCHS}" --breakdowns --spectral

# 5) Run with breakdowns
log "[ STEP 5 ] Run Rodinia (with breakdowns)"
run_in_dir "${CUDA_DIR}" env \
    RERUN_APPS=1 DO_BREAKDOWNS=1 LABEL="${LABEL}" OUT_DIR="${OUT_DIR}" \
    RUNS="${RUNS}" SLEEP_SECS="${SLEEP_SECS}" GPU_ID="${GPU_ID}" \
    ./runRodiniaWithIntervals.sh

# 6) Plot breakdowns
log "[ STEP 6 ] Plot breakdowns"
run_in_dir "${REPO_ROOT}" ./run_plot_breakdowns.sh

log "[ DONE ]"
