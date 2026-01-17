#!/bin/bash

set -e

source "$(dirname "$0")"/../util/args.sh "$@"
SCRIPT_DIR="$(realpath "$(dirname "$0")")"

GROMACS_VER="$(get_version gromacs)"

mkdir -p "${OUT_DIR}/gromacs"
cd "${OUT_DIR}/gromacs"

do_clone gromacs https://github.com/gromacs/gromacs.git ${GROMACS_VER}

if [ ${GROMACS_VER} = "2025.1" ]; then
  # Fix a few upstream bugs in 2025.1 to make non-MPI gromacs builds actually build.
  # (If you build a cuda-aware MPI using the scripts here, you should be able to
  # hook it up to GROMACS, too!).
  git -C "${OUT_DIR}/gromacs/gromacs" apply "${SCRIPT_DIR}/gromacs_patches.diff"
fi
