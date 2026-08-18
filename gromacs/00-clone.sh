#!/bin/bash

set -e

source "$(dirname "$0")"/../util/git.sh

GROMACS_VER="$(get_version gromacs)"

do_clone gromacs https://github.com/gromacs/gromacs.git ${GROMACS_VER}

# Fix cudaDeviceReset being called too early / in a race, which is undefined behaviour.
git -C gromacs apply "$(dirname "$0")/gromacs_patches.diff"
