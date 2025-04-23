#!/bin/bash

set -e
source "$(dirname "$0")"/../util/args.sh "$@"
cd "${OUT_DIR}/pytorch/build/torch/test"

export LD_LIBRARY_PATH="${OUT_DIR}/pytorch/install/usr/lib"

RETCODE=0
BROKEN=
for T in * ; do
    echo -e "\x1b[1m${T}\x1b[0m"

    set +e
    "./$T"
    R=$?
    set -e

    if [ "$R" != "0" ] ; then
        BROKEN="${BROKEN}\n${T}"
    fi
    RETCODE=2
done

echo -e "${BROKEN}"
exit $RETCODE
