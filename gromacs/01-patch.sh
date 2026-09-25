#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh

# Fix cudaDeviceReset being called too early / in a race, which is undefined behaviour.
git -C gromacs apply "$(dirname "$0")/gromacs_patches.diff"
