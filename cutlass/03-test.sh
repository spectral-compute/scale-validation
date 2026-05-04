#!/bin/bash

set -ETeuo pipefail

SCRIPT_DIR="$(realpath "$(dirname "$0")")"

LOGFILE="tests.log"
echo "Writing to $LOGFILE"
rm -f "$LOGFILE"

# Filter tests that fail.
#
# There are some common reasons for failure, including:
#  - Requiring more than 64 kiB of shared memory (not all GPUs have that).
#  - Small numerical differences.
#
# This list is generated with from runs on gfx1100 and gfx1201 with:
# cat tests.log | grep -E '^\[  FAILED  ] .*[^:)]$' | sed -E 's/.*?]//'
FILTERS="*:-:$(cat "${SCRIPT_DIR}/test-filter.txt" | sed -E 's/^ +//' | tr '\n' ':' | sed -E 's/:$//')"
echo "$FILTERS"

# List the test programs.
TESTS=(
    $(find build/test -type f -executable ! -name "*.so" ! -name "*.a" ! -name "*.o" | sort)
)

FAILURES=()

# Currently this runs every test under the same negative filter list.
set +e
for T in "${TESTS[@]}" ; do
    echo "======== ${T} ========" | tee -a "$LOGFILE"

    "${T}" --gtest_filter="${FILTERS}" |& tee -a "${LOGFILE}"
    if [ "$?" != "0" ] ; then
        FAILURES+=("${T}")
    fi
done
set -e

for T in "${FAILURES[@]}" ; do
    echo "Failed: ${T}"
done

set +e
echo "Summary"
grep -E '\[  PASSED  \] [0-9]* tests[.]' "$LOGFILE" | cut -d ' ' -f 6 | paste -sd+ | bc
grep -E '\[  FAILED  \] [0-9]* tests?, listed below:' "$LOGFILE" | cut -d ' ' -f 6 | paste -sd+ | bc

if [ "${#FAILURES[@]}" != "0" ] ; then
    exit 1
fi
