#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh

# The tests look for their data files under OPENCV_TEST_DATA_PATH.
OPENCV_TEST_DATA_PATH="$(pwd)/opencv_extra/testdata"
export OPENCV_TEST_DATA_PATH

RETCODE=0
BROKEN=()
for T in "$(pwd)"/install/bin/opencv_test_cuda*; do
    log "$(basename "$T")"

    set +e
    (cd "opencv_extra/testdata/gpu" && "$T")
    R=$?
    set -e

    if [ "$R" != "0" ]; then
        BROKEN+=("$T")
        RETCODE=2
    fi
done

echo -e "${BROKEN[@]}"
exit $RETCODE
