#!/bin/bash

set -o errtrace
set -o functrace
set -o nounset


SCRIPT_DIR="$(realpath "$(dirname "$0")")"
source "${SCRIPT_DIR}"/../util/args.sh "$@"

cd "${OUT_DIR}/cutlass/build"

LOGFILE=${OUT_DIR}/cutlass/build/tests.log

echo "Writing to $LOGFILE"

TESTS=(
    $(find test -type f -executable | sort)
)

FAILURES=()
for T in "${TESTS[@]}" ; do
    echo "======== ${T} ========"
    "${T}" >> $LOGFILE
    if [ "$?" != "0" ] ; then
        FAILURES+=("${T}")
    fi
done

for T in "${FAILURES[@]}" ; do
    echo "Failed: ${T}"
done
if [ ! -z "${FAILURES}" ] ; then
    exit 1
fi

echo "Cutlass test script finished"
exit 0
