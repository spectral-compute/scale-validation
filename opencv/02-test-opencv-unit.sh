#!/bin/bash

set -e
source "$(dirname "$0")"/../util/args.sh "$@"
cd "${OUT_DIR}/opencv/opencv_extra/testdata/gpu"

RETCODE=0
BROKEN=
for T in ../../../install/bin/opencv_test_cuda* ; do
    echo -e "\x1b[1m${T}\x1b[0m"

    set +e
    "./$T"
    R=$?
    set -e

    if [ "$R" != "0" ] ; then
        BROKEN="${BROKEN}\n${T}"
        RETCODE=2
    fi
done

echo -e "${BROKEN}"
exit $RETCODE
