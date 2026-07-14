#!/bin/bash

set -e

USAGE=$(cat <<-END

    Usage: $0 WORKDIR PATH_TO_SCALE GPU_ARCHITECTURE TEST_NAME

    - WORKDIR
        A directory for the script to work in. Compilation results will
        go here.

    - PATH_TO_SCALE
        The path where SCALE is installed.

    - GPU_ARCHITECTURE
        The AMD GPU archiecture to build for, eg "gfx1100".

    - TEST_NAME
        The name of one of the test directories in this repo.

END
)

if [[ $# -lt 3 ]] ; then
    echo "${USAGE}" 1>&2
    exit 1
fi

TEST_DIR="$(realpath "$(dirname "$0")")"
OUT_DIR="$(realpath "$1")"
SCALE_DIR="$(realpath "$2")"
INPUT_GPU_ARCH="$3"
TEST="$4"

# The next argument should be a subdirectory of the directory this script is in.
if [ "$TEST" == "util" ] || [ ! -d "${TEST_DIR}/${TEST}" ] ; then
    echo "Unknown test: ${TEST}" 2>&1
    exit 1
fi

rm -rf "${OUT_DIR}/${TEST}"
mkdir -p "${OUT_DIR}/${TEST}"
cd "${OUT_DIR}/${TEST}"

# Activate SCALE or use Nvidia's CUDA.
if [ -e "${SCALE_DIR}/bin/scaleenv" ] ; then
    echo "Using SCALE at ${SCALE_DIR}"
    TEST_MODE="scale"
    source "${SCALE_DIR}/bin/scaleenv" $INPUT_GPU_ARCH

    # This also serves to conveniently explode if we accidentially end up using nvidia nvcc.
    export NVCC_PREPEND_FLAGS="-fdiagnostics-color=always"
    export CXXFLAGS="-fdiagnostics-color=always"
    export CFLAGS="-fdiagnostics-color=always"
    export CMAKE_COLOR_DIAGNOSTICS=ON

    # A buildsystem-independent way of avoiding warning spam.
    # These warnings matter, but nvidia ignores them and the torrent makes CI runs
    # overflow the output limit.
    export NVCC_APPEND_FLAGS="-Wno-deprecated-literal-operator -Wno-format -Wno-unknown-warning-option -Wno-ignored-qualifiers -Wno-cuda-wrong-side -Wno-unused-function -Wno-unused-local-typedef -Wno-unused-parameter -Wno-int-conversion -Wno-sign-conversion -Wno-shorten-64-to-32 -Wno-template-id-cdtor -Wno-switch -Wno-vla-cxx-extension -Wno-missing-template-arg-list-after-template-kw -Wno-deprecated-declarations -Wno-c++11-narrowing-const-reference -Wno-typename-missing -Wno-unknown-pragmas -Wno-inconsistent-missing-override -Wno-unused-private-field -Wno-sign-compare -Wno-pessimizing-move -Wno-unused-result -Wno-invalid-constexpr -Wno-unused-but-set-variable -Wno-unused-variable -Wno-unused-value -Wno-implicit-const-int-float-conversion -Wno-pass-failed"
elif [ ! -e "${SCALE_DIR}/bin/nvcc" ] ; then
    echo "${SCALE_DIR} is not a valid SCALE or NVIDIA CUDA installation directory!" 1>&2
    exit 1
else
    echo "Using NVIDIA CUDA at ${SCALE_DIR} (not SCALE)"
    TEST_MODE="nvidia-cuda"

    # Set environment variables that scaleenv sets. This exists because scaleenv makes sure all the CUDA environment
    # variables are set. That is helpful to the user of scaleenv (and the projects' build scripts), but they might not
    # be set if not using scaleenv. So this replicates the helpfulness of scaleenv when not using SCALE.
    export CUDA_DIR="${SCALE_DIR}"
    export CUDA_DIR="${SCALE_DIR}"
    export CUDA_HOME="${SCALE_DIR}"
    export CUDA_PATH="${SCALE_DIR}"
    export CUDA_ROOT="${SCALE_DIR}"
    export CUDA_CXX="${SCALE_DIR}/bin/nvcc"
    export CUDACXX="${SCALE_DIR}/bin/nvcc"
    export CUCC="${SCALE_DIR}/bin/nvcc"
    export CUDA_INC_DIR="${SCALE_DIR}/include"
    export PATH="${SCALE_DIR}/bin:${PATH-}"
    export CUDAARCHS="$(echo $INPUT_GPU_ARCH | sed -Ee 's|sm_||g')"
    export LD_LIBRARY_PATH="${SCALE_DIR}/lib64:${LD_LIBRARY_PATH-}"
    export LIBRARY_PATH="${SCALE_DIR}/lib64:${LIBRARY_PATH-}"
    export CPATH="${SCALE_DIR}/include:${CPATH-}"
    export CUDA_BIN_PATH="${SCALE_DIR}/bin"
fi

# Keep the build log comprehensible despite multi-core; build as much as
# possible to maximise info about what we are missing in the log.
export MAKEFLAGS="-O -k"

export TEST_GPU_ARCH="${INPUT_GPU_ARCH}"

# --- Durable logging setup ------------------------------------------------
# Logs live one level above the per-test workdir (OUT_DIR, not OUT_DIR/TEST)
# so they're shared across every project tested against this WORKDIR, and
# survive the "rm -rf OUT_DIR/TEST" wipe at the top of each run -- one
# timestamped file accumulates per invocation, nothing is overwritten.
LOG_DIR="${OUT_DIR}/logs"
mkdir -p "${LOG_DIR}"
TIMESTAMP="$(date -u +%Y%m%d%H%M%SZ)"
LOG_FILE="${LOG_DIR}/${TEST}-${TIMESTAMP}.log"
: > "${LOG_FILE}"

# util/checks.sh's check() appends PASS/FAIL rows here as scripts run (each a
# fresh child process, so this can't be an in-memory variable). Folded into
# the bottom of LOG_FILE and removed by finalize_log below once the run
# finishes, however it finishes (success, a failing script, or an unexpected
# error) -- must degrade gracefully when unset (standalone script runs
# outside test.sh).
RESULTS_TMP="$(mktemp)"
export SCALE_TEST_RESULTS_FILE="${RESULTS_TMP}"

declare -a SUMMARY_ROWS=()

# Unites the per-script summary and per-check results into one table, each
# script's row immediately followed by the checks it recorded (if any) --
# fixed-width KIND/SCRIPT/STATUS columns for easy grep/awk, freeform DETAIL
# last for human reading.
finalize_log() {
    local row name rc duration status check_script check_status check_label
    {
        echo ""
        echo "=== RESULTS ==="
        printf '%-6s  %-42s  %-6s  %s\n' "KIND" "SCRIPT" "STATUS" "DETAIL"
        for row in "${SUMMARY_ROWS[@]}"; do
            IFS=$'\t' read -r name rc duration <<< "${row}"
            if [ "${rc}" -eq 0 ]; then status="PASS"; else status="FAIL"; fi
            printf '%-6s  %-42s  %-6s  %s\n' \
                "SCRIPT" "${name}" "${status}" "exit=${rc} duration=${duration}s"

            if [ -s "${RESULTS_TMP}" ]; then
                while IFS=$'\t' read -r check_script check_status check_label; do
                    [ "${check_script}" == "${name}" ] || continue
                    printf '%-6s  %-42s  %-6s  %s\n' \
                        "CHECK" "${check_script}" "${check_status}" "${check_label}"
                done < "${RESULTS_TMP}"
            fi
        done
        true
    } >> "${LOG_FILE}"
    rm -f "${RESULTS_TMP}"
}
trap finalize_log EXIT

{
    echo "test:      ${TEST}"
    echo "gpu_arch:  ${INPUT_GPU_ARCH}"
    echo "scale_dir: ${SCALE_DIR}"
    echo "mode:      ${TEST_MODE}"
    echo "started:   $(date -u -Is)"
    echo ""
} | tee -a "${LOG_FILE}"

# Run all the scripts for the test.
set -o errexit
for i in "${TEST_DIR}/${TEST}"/*.sh; do
    NAME="$(basename "$i")"
    echo "--------------- Executing $i ---------------" | tee -a "${LOG_FILE}"

    # Errexit must not fire on the pipeline's own (tee's) exit status -- we
    # need to read the *script's* real exit code out of PIPESTATUS and decide
    # explicitly below, preserving today's abort-on-first-failure behaviour.
    SECONDS=0
    set +e
    stdbuf -oL -eL "$i" 2>&1 | tee -a "${LOG_FILE}"
    RC="${PIPESTATUS[0]}"
    set -e
    DURATION="${SECONDS}"

    SUMMARY_ROWS+=("$(printf '%s\t%s\t%s' "${NAME}" "${RC}" "${DURATION}")")

    if [ "${RC}" -ne 0 ] ; then
        echo "FAILED: ${NAME} (exit ${RC}) -- log: ${LOG_FILE}" | tee -a "${LOG_FILE}"
        exit "${RC}"
    fi
done

echo "ALL SCRIPTS PASSED -- log: ${LOG_FILE}" | tee -a "${LOG_FILE}"
