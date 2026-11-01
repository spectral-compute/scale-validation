#!/usr/bin/env bash
# shellcheck disable=2317,2329
. "$(dirname "$0")"/../util/prelude.sh
source "$SCALE_VALIDATION/util/checks.sh"

# Upstream has no ctest suite: its modular tests are self-checking executables that exit non-zero on
# failure. Run them from a scratch directory, since some write output files to the working directory.
SRC="$(realpath DEM-Engine/src/demo/ModularTests)"
BIN="$(realpath build/bin)"
OUT="$(realpath .)/test-output"
mkdir -p "${OUT}"
cd "${OUT}"

run_test() {
    timeout 1800 "${BIN}/$1" "${@:2}"
}

# The analytical cone tests default to writing under /tmp.
check DEMTest_AnalyticalCone run_test DEMTest_AnalyticalCone "${OUT}/AnalyticalCone"
check DEMTest_AnalyticalConePour run_test DEMTest_AnalyticalConePour "${OUT}/AnalyticalConePour"

# StateFinite injects NaN/Inf and expects a device trap, so upstream drives it from Python with one
# process per case.
check DEMTest_StateFinite python3 "${SRC}/test_state_finite.py" "${BIN}/DEMTest_StateFinite"

# Every other modular test upstream builds, so that one that failed to build counts as a failure.
mapfile -t TESTS < <(sed -n '/^SET(MODULAR_TESTS/,/^)/p' "${SRC}/CMakeLists.txt" | grep -o 'DEMTest_[A-Za-z0-9_]*')
[ "${#TESTS[@]}" -gt 0 ]
for t in "${TESTS[@]}"; do
    case "${t}" in
    DEMTest_AnalyticalCone | DEMTest_AnalyticalConePour | DEMTest_StateFinite | DEMTest_Visualizer) ;;
    *) check "${t}" run_test "${t}" ;;
    esac
done

check_exit
