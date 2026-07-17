#!/usr/bin/env bash

set -ETeuo pipefail

# Keep PyTorch on the GPU selected by CI
# Fall back to the first GPU when CI has not already selected one
export CUDA_VISIBLE_DEVICES="${CUDA_VISIBLE_DEVICES:-0}"

# Do not let packages from the runner's user site leak into the PyTorch venv
export PYTHONNOUSERSITE=1

SCRIPT_DIR="$(realpath "$(dirname "${BASH_SOURCE[0]}")")"
SUITE_ROOT="${SCRIPT_DIR}/pytorch_extended_tests"
OUT_DIR="$(realpath .)"
SRCROOT="${OUT_DIR}/pytorch"
RESULTS_DIR="/tmp/ci_benchmarks/pytorch"

if [[ ! -d "${SUITE_ROOT}" ]]; then
    echo "Could not find the test suite in ${SUITE_ROOT}"
    exit 1
fi

if [[ ! -d "${SRCROOT}" ]]; then
    echo "Could not find the PyTorch source tree in ${SRCROOT}"
    exit 1
fi

if [[ ! -f "${SRCROOT}/.venv/bin/activate" ]]; then
    echo "Could not find .venv in ${SRCROOT}"
    exit 1
fi

cd "${SRCROOT}"
source "${SRCROOT}/.venv/bin/activate"

PYTHON="${PYTHON:-python}"

if ! command -v "${PYTHON}" >/dev/null 2>&1; then
    echo "Could not find Python executable: ${PYTHON}"
    exit 1
fi

cd "${SUITE_ROOT}"

# Start clean so the CI artefact only contains this run
rm -rf "${RESULTS_DIR}"
mkdir -p "${RESULTS_DIR}"

# Keep both the src package and root config package importable
export PYTHONPATH="${SUITE_ROOT}/src:${SUITE_ROOT}${PYTHONPATH:+:${PYTHONPATH}}"

# Use unbuffered Python output so CI logs remain useful during a long run
export PYTHONUNBUFFERED=1

echo "Running pytorch_extended_tests"
echo "PyTorch source tree: ${SRCROOT}"
echo "Python: $(command -v "${PYTHON}")"
echo "CUDA_VISIBLE_DEVICES=${CUDA_VISIBLE_DEVICES}"
echo "Writing results to ${RESULTS_DIR}/"

# Capture the full log but still return the suite's real exit status
set +e
"${PYTHON}" -u -m pytorch_extended_tests.orchestrator.run_suite \
    --results-dir "${RESULTS_DIR}" \
    --keep-existing \
    "$@" \
    |& tee "${RESULTS_DIR}/execution.log"
PIPE_STATUSES=("${PIPESTATUS[@]}")
set -e

SUITE_STATUS="${PIPE_STATUSES[0]}"
TEE_STATUS="${PIPE_STATUSES[1]}"

echo "Results are available in ${RESULTS_DIR}/"

if [[ "${TEE_STATUS}" -ne 0 ]]; then
    echo "Failed to write ${RESULTS_DIR}/execution.log"
    exit "${TEE_STATUS}"
fi

exit "${SUITE_STATUS}"
