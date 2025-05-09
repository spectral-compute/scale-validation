#!/bin/bash

set -e
source "$(dirname "$0")"/../util/args.sh "$@"
SCRIPT_DIR="$(realpath "$(dirname "$0")")"
source "${SCRIPT_DIR}"/../util/args.sh "$@"

mkdir -p "${OUT_DIR}/gromacs"
cd "${OUT_DIR}/gromacs"
git clone https://github.com/gromacs/gromacs.git 
cd gromacs
git checkout release-2025
git apply "${SCRIPT_DIR}/gromacs_patches.diff" ## required to compile with scale not native
cd ..
GROMACS_VER=2025.1
wget -q https://ftp.gromacs.org/regressiontests/regressiontests-${GROMACS_VER}.tar.gz
tar xf regressiontests-${GROMACS_VER}.tar.gz
