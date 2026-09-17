#!/usr/bin/env bash

set -e

USAGE=$(
    cat <<-END

    Usage: $0 WORKDIR PATH_TO_TOOLKIT GPU_ARCHITECTURE TEST_NAME [--match REGEX] [--keep]

    - WORKDIR
        A directory for the script to work in. Compilation results will
        go here.

    - PATH_TO_TOOLKIT
        The path where the toolkit under test is installed. This may be a
        SCALE, ROCm, or NVIDIA CUDA installation; which one it is decides
        the compiler used (see "Mode selection" below).

    - GPU_ARCHITECTURE
        The GPU archiecture to build for: an AMD arch such as "gfx1100"
        (optionally with feature suffixes, eg "gfx90a:xnack+") to target AMD,
        or an NVIDIA arch such as "sm_120" to target NVIDIA.

    Mode selection
        The toolkit path and the GPU architecture are independent: the path
        decides the *compiler*, the architecture decides the *target vendor*.
        The four supported combinations are:

            /opt/scale        + gfx1100  ->  scale-amd
            /opt/scale        + sm_120   ->  scale-nvidia
            /usr/local/cuda   + sm_120   ->  nvcc-nvidia
            /opt/rocm         + gfx1100  ->  hip-amd

        Nothing here inspects the machine's hardware, so this stays correct on
        heterogeneous machines that have both AMD and NVIDIA GPUs installed.

    - TEST_NAME
        The name of one of the test directories in this repo.

    - --match REGEX (optional)
        Only run scripts whose filename matches REGEX (bash =~), instead of
        every "*.sh" in the test directory. Useful for running just the
        test/benchmark scripts against an already-built project, e.g.
        "-(test|benchmark)".

    - --keep (optional)
        Don't wipe WORKDIR/TEST_NAME before running. Use this to run scripts
        against a directory that already has clone/build output in it (e.g.
        one populated by an earlier build stage), instead of starting fresh.

END
)

if [[ $# -lt 3 ]]; then
    echo "${USAGE}" 1>&2
    exit 1
fi

TEST_DIR="$(realpath "$(dirname "$0")")"
OUT_DIR="$(realpath "$1")"
TOOLKIT_DIR="$(realpath "$2")"
INPUT_GPU_ARCH="$3"
TEST="$4"
shift 4

MATCH_REGEX=""
KEEP=""
while [[ $# -gt 0 ]]; do
    case "$1" in
    --match)
        MATCH_REGEX="$2"
        shift 2
        ;;
    --keep)
        KEEP=1
        shift
        ;;
    *)
        echo "${USAGE}" 1>&2
        exit 1
        ;;
    esac
done

# The next argument should be a subdirectory of the directory this script is in.
if [ "$TEST" == "util" ] || [ ! -d "${TEST_DIR}/${TEST}" ]; then
    echo "Unknown test: ${TEST}" 2>&1
    exit 1
fi

if [ -n "${KEEP}" ]; then
    mkdir -p "${OUT_DIR}/${TEST}"
else
    rm -rf "${OUT_DIR:?}/${TEST:?}"
    mkdir -p "${OUT_DIR}/${TEST}"
fi
cd "${OUT_DIR}/${TEST}"

# On RHEL 8, use an appstream compiler, if available
# This avoids problems coming from projects that require a new-ish version of GCC
. /etc/os-release
if [[ "${PLATFORM_ID:-}" == "platform:el8" ]]; then
    . /opt/rh/gcc-toolset-15/enable || true
fi

# Work out which mode we are running in. This is two independent questions --
# which toolchain compiles the code, and which vendor's GPU it targets -- and
# they are answered from the two arguments, never by probing the machine. A
# validation machine may well have both AMD and NVIDIA hardware (and both
# vendors' drivers) installed, so sniffing for devices would pick the wrong
# answer; the arguments the caller passed are the only reliable signal.

# The GPU architecture names the target vendor unambiguously. Feature suffixes
# ("gfx90a:xnack+") and bare NVIDIA arch numbers ("120") are both accepted.
case "${INPUT_GPU_ARCH}" in
    gfx*)
        TEST_VENDOR="amd"
        ;;
    sm_*|compute_*|[0-9]*)
        TEST_VENDOR="nvidia"
        ;;
    *)
        echo "Unrecognised GPU architecture \"${INPUT_GPU_ARCH}\": expected an AMD arch (gfx...) or an NVIDIA arch (sm_...)" 1>&2
        exit 1
        ;;
esac

# The layout of the install directory names the toolchain. The order of these
# probes matters: a SCALE installation also provides bin/nvcc, so SCALE has to
# be ruled in before NVIDIA CUDA is considered, or every SCALE run would be
# misidentified as a stock-CUDA one.
if [ -e "${TOOLKIT_DIR}/bin/scaleenv" ] ; then
    TEST_TOOLCHAIN="scale"
elif [ -e "${TOOLKIT_DIR}/bin/hipconfig" ] || [ -e "${TOOLKIT_DIR}/bin/hipcc" ] ; then
    TEST_TOOLCHAIN="hip"
elif [ -e "${TOOLKIT_DIR}/bin/nvcc" ] ; then
    TEST_TOOLCHAIN="nvcc"
else
    echo "${TOOLKIT_DIR} is not a valid SCALE, ROCm, or NVIDIA CUDA installation directory!" 1>&2
    exit 1
fi

TEST_MODE="${TEST_TOOLCHAIN}-${TEST_VENDOR}"

# Two of the six toolchain/vendor pairings are not supported: nvcc cannot emit
# AMD code at all, and while hipcc can in principle target NVIDIA via CUDA, we
# do not test that configuration -- rejecting it here beats letting a run limp
# along in a mode nobody validated.
case "${TEST_MODE}" in
    scale-amd|scale-nvidia)
        echo "Using SCALE at ${TOOLKIT_DIR}, targeting ${INPUT_GPU_ARCH}"
        source "${TOOLKIT_DIR}/bin/scaleenv" $INPUT_GPU_ARCH

        # This also serves to conveniently explode if we accidentially end up using nvidia nvcc.
        export NVCC_PREPEND_FLAGS="-fdiagnostics-color=always"
        export CXXFLAGS="-fdiagnostics-color=always"
        export CFLAGS="-fdiagnostics-color=always"
        export CMAKE_COLOR_DIAGNOSTICS=ON

        # A buildsystem-independent way of avoiding warning spam.
        # These warnings matter, but nvidia ignores them and the torrent makes CI runs
        # overflow the output limit.
        export NVCC_APPEND_FLAGS="-Wno-deprecated-literal-operator -Wno-format -Wno-unknown-warning-option -Wno-ignored-qualifiers -Wno-cuda-wrong-side -Wno-unused-function -Wno-unused-local-typedef -Wno-unused-parameter -Wno-int-conversion -Wno-sign-conversion -Wno-shorten-64-to-32 -Wno-template-id-cdtor -Wno-switch -Wno-vla-cxx-extension -Wno-missing-template-arg-list-after-template-kw -Wno-deprecated-declarations -Wno-c++11-narrowing-const-reference -Wno-typename-missing -Wno-unknown-pragmas -Wno-inconsistent-missing-override -Wno-unused-private-field -Wno-sign-compare -Wno-pessimizing-move -Wno-unused-result -Wno-invalid-constexpr -Wno-unused-but-set-variable -Wno-unused-variable -Wno-unused-value -Wno-implicit-const-int-float-conversion -Wno-pass-failed"
        ;;

    nvcc-nvidia)
        echo "Using NVIDIA CUDA at ${TOOLKIT_DIR} (not SCALE)"

        # Set environment variables that scaleenv sets. This exists because scaleenv makes sure all the CUDA environment
        # variables are set. That is helpful to the user of scaleenv (and the projects' build scripts), but they might not
        # be set if not using scaleenv. So this replicates the helpfulness of scaleenv when not using SCALE.
        export CUDA_DIR="${TOOLKIT_DIR}"
        export CUDA_HOME="${TOOLKIT_DIR}"
        export CUDA_PATH="${TOOLKIT_DIR}"
        export CUDA_ROOT="${TOOLKIT_DIR}"
        export CUDA_CXX="${TOOLKIT_DIR}/bin/nvcc"
        export CUDACXX="${TOOLKIT_DIR}/bin/nvcc"
        export CUCC="${TOOLKIT_DIR}/bin/nvcc"
        export CUDA_INC_DIR="${TOOLKIT_DIR}/include"
        export PATH="${TOOLKIT_DIR}/bin:${PATH-}"
        export CUDAARCHS="$(echo $INPUT_GPU_ARCH | sed -Ee 's|sm_||g')"
        export LD_LIBRARY_PATH="${TOOLKIT_DIR}/lib64:${LD_LIBRARY_PATH-}"
        export LIBRARY_PATH="${TOOLKIT_DIR}/lib64:${LIBRARY_PATH-}"
        export CPATH="${TOOLKIT_DIR}/include:${CPATH-}"
        export CUDA_BIN_PATH="${TOOLKIT_DIR}/bin"
        ;;

    hip-amd)
        echo "Using ROCm/HIP at ${TOOLKIT_DIR}"

        # As with the nvcc-nvidia branch above, there is no "hipenv" to source,
        # so set by hand the variables ROCm's own build integration and the
        # projects' build systems expect to find.
        #
        # TODO: this set is a starting point -- fill in / adjust as the HIP
        # tests are brought up. Anything a project needs should be exported
        # here rather than hardcoded in the per-project scripts.
        export ROCM_PATH="${TOOLKIT_DIR}"
        export ROCM_HOME="${TOOLKIT_DIR}"
        export HIP_PATH="${TOOLKIT_DIR}"
        export HIP_PLATFORM="amd"
        export HIP_COMPILER="clang"
        export HIP_RUNTIME="rocclr"
        export HIP_CLANG_PATH="${TOOLKIT_DIR}/llvm/bin"
        export HIPCXX="${TOOLKIT_DIR}/bin/hipcc"
        export PATH="${TOOLKIT_DIR}/bin:${PATH-}"
        export LD_LIBRARY_PATH="${TOOLKIT_DIR}/lib:${LD_LIBRARY_PATH-}"
        export LIBRARY_PATH="${TOOLKIT_DIR}/lib:${LIBRARY_PATH-}"
        export CPATH="${TOOLKIT_DIR}/include:${CPATH-}"
        export CMAKE_PREFIX_PATH="${TOOLKIT_DIR}:${CMAKE_PREFIX_PATH-}"

        # The HIP-side spellings of CUDAARCHS. GPU_TARGETS is what modern
        # ROCm/CMake reads; AMDGPU_TARGETS is the older name still honoured by
        # several of the projects under test.
        export GPU_TARGETS="${INPUT_GPU_ARCH}"
        export AMDGPU_TARGETS="${INPUT_GPU_ARCH}"
        export PYTORCH_ROCM_ARCH="${INPUT_GPU_ARCH}"

        export CXXFLAGS="-fdiagnostics-color=always"
        export CFLAGS="-fdiagnostics-color=always"
        export CMAKE_COLOR_DIAGNOSTICS=ON
        ;;

    *)
        echo "Unsupported combination: the ${TEST_TOOLCHAIN} toolchain at ${TOOLKIT_DIR} cannot target ${TEST_VENDOR} (${INPUT_GPU_ARCH})" 1>&2
        exit 1
        ;;
esac

# Exported so the per-project scripts can branch on the mode. TEST_MODE is the
# combined "<toolchain>-<vendor>" string; the two halves are exported
# separately so a script that only cares about one axis does not have to
# pattern-match the combined form.
export TEST_MODE
export TEST_TOOLCHAIN
export TEST_VENDOR

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
: >"${LOG_FILE}"

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
            IFS=$'\t' read -r name rc duration <<<"${row}"
            if [ "${rc}" -eq 0 ]; then status="PASS"; else status="FAIL"; fi
            printf '%-6s  %-42s  %-6s  %s\n' \
                "SCRIPT" "${name}" "${status}" "exit=${rc} duration=${duration}s"

            if [ -s "${RESULTS_TMP}" ]; then
                while IFS=$'\t' read -r check_script check_status check_label; do
                    [ "${check_script}" == "${name}" ] || continue
                    printf '%-6s  %-42s  %-6s  %s\n' \
                        "CHECK" "${check_script}" "${check_status}" "${check_label}"
                done <"${RESULTS_TMP}"
            fi
        done
        true
    } >>"${LOG_FILE}"
    rm -f "${RESULTS_TMP}"
}
trap finalize_log EXIT

{
    echo "test:      ${TEST}"
    echo "gpu_arch:  ${INPUT_GPU_ARCH}"
    echo "toolkit:   ${TOOLKIT_DIR}"
    echo "mode:      ${TEST_MODE}"
    echo "started:   $(date -u -Is)"
    echo ""
} | tee -a "${LOG_FILE}"

# Run all the scripts for the test.
set -o errexit
for i in "${TEST_DIR}/${TEST}"/*.sh; do
    NAME="$(basename "$i")"

    if [ -n "${MATCH_REGEX}" ] && [[ ! "${NAME}" =~ ${MATCH_REGEX} ]]; then
        continue
    fi

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

    if [ "${RC}" -ne 0 ]; then
        echo "FAILED: ${NAME} (exit ${RC}) -- log: ${LOG_FILE}" | tee -a "${LOG_FILE}"
        exit "${RC}"
    fi
done

echo "ALL SCRIPTS PASSED -- log: ${LOG_FILE}" | tee -a "${LOG_FILE}"
