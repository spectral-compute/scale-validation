#!/bin/bash

set -e
source "$(dirname "$0")"/../util/args.sh "$@"
cd "${OUT_DIR}/gromacs/regressiontests-2024.4"

source "${OUT_DIR}/gromacs/install/bin/GMXRC"

OUT="${OUT_DIR}/gromacs/regression-test.txt"

set +e
./gmxtest.pl all 2>&1 | tee "${OUT}"

# Unfortunately, not all of the tests pass (even on Nvidia). So we check the number of PASSEDs and Abnormals.
PASSED="$(grep -F PASSED "${OUT}" | wc -l)"
ABNORMAL="$(grep -F Abnormal "${OUT}" | wc -l)"

echo "Number of passes: ${PASSED}"
echo "Number of abnormals: ${ABNORMAL}"

if [ "${PASSED}" != "132" ] ; then
    echo "Incorrect number of passing tests!"
    exit 1
fi
if [ "${ABNORMAL}" != "14" ] ; then
    echo "Incorrect number of abnormal tests!"
    exit 1
fi
echo "GROMACS regression tests performed as expected :)"