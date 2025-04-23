#!/bin/bash

set -e
source "$(dirname "$0")"/../util/args.sh "$@"
cd "${OUT_DIR}/gromacs/regressiontests-2024.4"

source "${OUT_DIR}/gromacs/install/bin/GMXRC"

set +e
./gmxtest.pl all

if [ "$?" != "0" ] ; then
    exit 222
fi
