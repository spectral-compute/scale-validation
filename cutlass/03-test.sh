#!/bin/bash

# set -ETeuo pipefail # Script previously started with this, unrolling them
set -o errtrace
set -o functrace
set -o errexit
set -o nounset
set -o pipefail


SCRIPT_DIR="$(realpath "$(dirname "$0")")"
source "${SCRIPT_DIR}"/../util/args.sh "$@"

cd "${OUT_DIR}/cutlass/build"

LOGFILE=${OUT_DIR}/cutlass/build/tests.log

echo "Writing to $LOGFILE"

TESTS=(
    $(find test -type f -executable | sort)
)

set +e
FAILURES=()
for T in "${TESTS[@]}" ; do
    echo "======== ${T} ========"
    "${T}" >> $LOGFILE
    if [ "$?" != "0" ] ; then
        FAILURES+=("${T}")
    fi
done
set -e

for T in "${FAILURES[@]}" ; do
    echo "Failed: ${T}"
done
if [ ! -z "${FAILURES}" ] ; then
    exit 1
fi
