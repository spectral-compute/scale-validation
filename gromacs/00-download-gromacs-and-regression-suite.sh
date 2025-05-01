#!/bin/bash

set -e
source "$(dirname "$0")"/../util/args.sh "$@"

mkdir -p "${OUT_DIR}/gromacs"
cd "${OUT_DIR}/gromacs"

GROMACS_VER=2024.4

wget -q http://ftp.gromacs.org/pub/gromacs/gromacs-${GROMACS_VER}.tar.gz
wget -q https://ftp.gromacs.org/regressiontests/regressiontests-${GROMACS_VER}.tar.gz

tar xf gromacs-${GROMACS_VER}.tar.gz
tar xf regressiontests-${GROMACS_VER}.tar.gz
