#!/bin/bash

set -e
set -o xtrace

GROMACS_VER=2025.1

source "$(dirname "$0")"/../util/args.sh "$@"
SCRIPT_DIR="$(realpath "$(dirname "$0")")"
source "${SCRIPT_DIR}"/../util/args.sh "$@"

mkdir -p "${OUT_DIR}/gromacs"
cd "${OUT_DIR}/gromacs"

do_clone gromacs https://github.com/gromacs/gromacs.git v${GROMACS_VER}

# Fix a few upstream bugs to make non-MPI gromacs builds actually build.
# (If you build a cuda-aware MPI using the scripts here, you should be able to
# hook it up to GROMACS, too!).
git -C "${OUT_DIR}/gromacs/gromacs" apply "${SCRIPT_DIR}/gromacs_patches.diff"

wget -q https://ftp.gromacs.org/regressiontests/regressiontests-${GROMACS_VER}.tar.gz
tar xf regressiontests-${GROMACS_VER}.tar.gz
