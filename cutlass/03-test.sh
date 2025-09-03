#!/bin/bash

set -ETeuo pipefail
SCRIPT_DIR="$(realpath "$(dirname "$0")")"
source "${SCRIPT_DIR}"/../util/args.sh "$@"

cd "${OUT_DIR}/cutlass/build"

TESTS=(
    $(find test -type f -perm /100 | sort)
)

set +e
FAILURES=()
for T in "${TESTS[@]}" ; do
    echo "======== ${T} ========"
    "${T}"
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
