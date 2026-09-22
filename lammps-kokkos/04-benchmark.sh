#!/bin/bash

set -eo pipefail

# see other LAMMPS folder for comments, these two should be kept in sync. Or shared, even, really.
cd "lammps-kokkos/bench"

LMP="../../build/lmp"
KK_ARGS=(-k on g 1 -sf kk -pk kokkos newton on neigh half)

declare -A STYLE=( [lj]=lj/cut/kk [eam]=eam/kk )


for BENCH in lj eam ; do
    echo "--- Running bench/in.${BENCH} ---"
    "${LMP}" "${KK_ARGS[@]}" -in "in.${BENCH}" -log "bench-${BENCH}.log"

    grep -E '^(Loop time of|Performance:)' "bench-${BENCH}.log"
    grep -F "${STYLE[${BENCH}]}" "bench-${BENCH}.log"
done
