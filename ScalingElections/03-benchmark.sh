#!/bin/bash
set -ETeuo pipefail

SCRIPT_DIR="$(realpath "$(dirname "$0")")"
source "${SCRIPT_DIR}"/../util/args.sh "$@"   # expects OUT_DIR, etc.

APP_ROOT="${OUT_DIR}/scaling-elections"
APP_DIR="${APP_ROOT}/ScalingElections"
SCRIPT="${APP_DIR}/scaling_elections.py"

LOGFILE="${APP_ROOT}/tests.log"
JUNIT="${APP_ROOT}/scaling-elections-tests.xml"

# Use the SAME venv created in build.sh
source "${APP_DIR}/.venv/bin/activate"

# Normalize CUDA env (same as in build.sh) so runtime finds libs
RAW_CUDA_PATH="${CUDA_PATH}"
if [[ -x "${RAW_CUDA_PATH}/bin/nvcc" ]]; then
  NORM_CUDA_PATH="${RAW_CUDA_PATH}"
else
  NORM_CUDA_PATH="$(cd "${RAW_CUDA_PATH}/../.." && pwd)"
fi
export CUDA_PATH="${NORM_CUDA_PATH}"
export CUDA_HOME="${NORM_CUDA_PATH}"
export PATH="${CUDA_PATH}/bin:${PATH}"
export LD_LIBRARY_PATH="${CUDA_PATH}/lib64:${CUDA_PATH}/lib:${LD_LIBRARY_PATH:-}"

# Force unbuffered / line-buffered output so device info appears up-front
export PYTHONUNBUFFERED=1

: > "$LOGFILE"

# Same matrix as run_mojo.sh
#   "CANDS  WARMUP  REPEAT"
runs=(
  "2048   1 20"
  "4096   1 10"
  "8192   1 5"
  "16384  1 3"
  "32768  1 1"
)

RUN_GPU="--run-gpu"

RCS=()
FAIL=0

pushd "${APP_DIR}" >/dev/null

echo "== venv =="
python -V
# Ensure numba/llvmlite/numpy are present and compatible (known-good pins)
python - <<'PY' || python -m pip install -q --upgrade "numpy==1.26.*" "numba==0.60.*" "llvmlite==0.43.*"
try:
    import numpy, numba, llvmlite  # noqa: F401
except Exception:
    raise SystemExit(1)
PY
python -c "import numpy, numba, llvmlite; print('numpy', numpy.__version__, '| numba', numba.__version__, '| llvmlite', llvmlite.__version__)"

run_one() {
  local CANDS="$1" WARMUP="$2" REPEAT="$3"
  echo "=== ${CANDS} candidates (warmup=${WARMUP}, repeat=${REPEAT}) ===" | tee -a "$LOGFILE"
  # Keep line order when piping through tee
  stdbuf -oL -eL python -u "${SCRIPT}" \
    --num-candidates "${CANDS}" \
    --num-voters 0 \
    ${RUN_GPU} \
    --no-serial \
    --warmup "${WARMUP}" \
    --repeat "${REPEAT}" 2>&1 | tee -a "$LOGFILE"
  return ${PIPESTATUS[0]}
}

for r in "${runs[@]}"; do
  set -- $r
  CANDS="$1"; WARMUP="$2"; REPEAT="$3"
  if run_one "${CANDS}" "${WARMUP}" "${REPEAT}"; then
    RCS+=( 0 )
  else
    RCS+=( 1 ); FAIL=1
  fi
  echo | tee -a "$LOGFILE"
done

popd >/dev/null

# JUnit
{
  echo '<?xml version="1.0" encoding="UTF-8"?>'
  echo "<testsuite name=\"scaling_elections\" tests=\"${#RCS[@]}\">"
  for i in "${!RCS[@]}"; do
    name="run_$((i+1))"
    if (( RCS[i] == 0 )); then
      echo "  <testcase classname=\"scaling_elections\" name=\"${name}\"/>"
    else
      echo "  <testcase classname=\"scaling_elections\" name=\"${name}\"><failure message=\"exit code ${RCS[i]}\"/></testcase>"
    fi
  done
  echo '</testsuite>'
} > "$JUNIT"

echo "Log:   $LOGFILE"
echo "JUnit: $JUNIT"
exit $FAIL
