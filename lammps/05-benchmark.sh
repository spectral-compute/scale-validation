#!/bin/bash

set -eo pipefail

# LAMMPS's own benchmark problems. Each is 32,000 atoms for 100 timesteps.
# For performance only; correctness assertion is all in 03-test-examples.sh

cd "lammps/bench"

LMP="../../build/lmp"

# in.lj:  atomic fluid, Lennard-Jones, 55 neighbours per atom (lj/cut/gpu)
# in.eam: metallic solid, Cu EAM potential, 45 neighbours per atom (eam/gpu, uses MANYBODY package)
#
declare -A STYLE=( [lj]=lj/cut [eam]=eam )

for BENCH in lj eam ; do
    echo "--- Running bench/in.${BENCH} ---"
    "${LMP}" -sf gpu -pk gpu 1 -in "in.${BENCH}" -log "bench-${BENCH}.log" \
        > "bench-${BENCH}.screen.log" 2>&1

    grep -E '^(Loop time of|Performance:)' "bench-${BENCH}.log"
    grep -F "Using acceleration for ${STYLE[${BENCH}]}:" "bench-${BENCH}.screen.log"
done
