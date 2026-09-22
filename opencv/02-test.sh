#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh
raise_error_if_using_rocm

RETCODE=0
BROKEN=()
for T in "$(pwd)"/install/bin/opencv_test_cuda*; do
    log "$(basename "$T")"

    set +e
    (cd "opencv/opencv_extra/testdata/gpu" && "$T")
    R=$?
    set -e

    if [ "$R" != "0" ]; then
        BROKEN+=("$T")
        RETCODE=2
    fi
done

echo -e "${BROKEN[@]}"
exit $RETCODE
