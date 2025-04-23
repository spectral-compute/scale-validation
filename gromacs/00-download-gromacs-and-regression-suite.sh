#!/bin/bash

set -e
source "$(dirname "$0")"/../util/args.sh "$@"

mkdir -p "${OUT_DIR}/gromacs"
cd "${OUT_DIR}/gromacs"

wget -q http://ftp.gromacs.org/pub/gromacs/gromacs-2024.4.tar.gz
wget -q https://ftp.gromacs.org/regressiontests/regressiontests-2024.4.tar.gz

tar xf gromacs-2024.4.tar.gz
tar xf regressiontests-2024.4.tar.gz
