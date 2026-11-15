#!/usr/bin/env bash
# shellcheck source-path=SCRIPTDIR
. "$(dirname "$0")"/../../util/prelude.sh

# LAMMPS's own bench/ problems on the GPU package, each at 1x1x1, 2x2x2 and
# 4x4x4 replication (32,000 to 2,048,000 atoms), 100 timesteps each. The
# smallest finish in well under a second, so launch overhead dominates;
# the largest are GPU-bound.
#   lj:    atomic fluid, Lennard-Jones (lj/cut)
#   eam:   copper, embedded-atom method (eam)
#   chain: bead-spring polymer melt, FENE bonds (lj/cut)
#   rhodo: rhodopsin protein in water, CHARMM + PPPM (lj/charmm/coul/long)
# in.chute is left out: its granular pair style has no GPU version.
OUT="${RESULTS_DIR:-$(realpath .)}/lammps.${BENCHMARK_COMPILER:-unknown}"
OUT+=".${TEST_GPU_ARCH}.$(date -u +%Y%m%d%H%M%S).csv"
cd "lammps/bench"
LMP="../../build/lmp"
declare -A INPUT=([lj]=in.lj [eam]=in.eam [chain]=in.chain.scaled
    [rhodo]=in.rhodo.scaled)
declare -A STYLE=([lj]=lj/cut [eam]=eam [chain]=lj/cut
    [rhodo]=lj/charmm/coul/long)

echo "bench,replicas,atoms,steps,loop_s,timesteps_per_s" >"${OUT}"
for BENCH in lj eam chain rhodo; do
    for R in 1 2 4; do
        NAME="${BENCH}-x${R}"
        log "--- Running bench/${INPUT[${BENCH}]}, ${R}x${R}x${R} ---"
        "${LMP}" -sf gpu -pk gpu 1 -var x "${R}" -var y "${R}" -var z "${R}" \
            -in "${INPUT[${BENCH}]}" -log "bench-${NAME}.log" \
            >"bench-${NAME}.screen.log" 2>&1
        grep -E '^(Loop time of|Performance:)' "bench-${NAME}.log"
        grep -F "Using acceleration for ${STYLE[${BENCH}]}:" \
            "bench-${NAME}.screen.log"
        # Loop time of 0.39 on 1 procs for 100 steps with 32000 atoms
        sed -nE 's/^Loop time of ([0-9.e+-]+) on [0-9]+ procs for ([0-9]+) steps with ([0-9]+) atoms.*/\1 \2 \3/p' \
            "bench-${NAME}.log" | while read -r t steps atoms; do
            echo "${BENCH},${R},${atoms},${steps},${t},$(python3 -c "print(${steps} / ${t})")"
        done >>"${OUT}"
    done
done
cat "${OUT}"
[[ "$(wc -l <"${OUT}")" -eq 13 ]]
