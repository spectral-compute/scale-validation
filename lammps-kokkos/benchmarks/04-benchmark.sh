#!/usr/bin/env bash
# shellcheck source-path=SCRIPTDIR
. "$(dirname "$0")"/../../util/prelude.sh

# lammps/benchmarks/05-benchmark.sh's problems, on the KOKKOS package: each
# at 1x1x1, 2x2x2 and 4x4x4 replication (32,000 to 2,048,000 atoms), 100
# timesteps. See that script for what each problem is.
OUT="${RESULTS_DIR:-$(realpath .)}/lammps-kokkos.${BENCHMARK_COMPILER:-unknown}"
OUT+=".${TEST_GPU_ARCH}.$(date -u +%Y%m%d%H%M%S).csv"
cd "lammps-kokkos/bench"
LMP="../../build/lmp"
KK_ARGS=(-k on g 1 -sf kk -pk kokkos newton on neigh half)
declare -A INPUT=([lj]=in.lj [eam]=in.eam [chain]=in.chain.scaled
    [rhodo]=in.rhodo.scaled)
declare -A STYLE=([lj]=lj/cut/kk [eam]=eam/kk [chain]=lj/cut/kk
    [rhodo]=lj/charmm/coul/long/kk)

echo "bench,replicas,atoms,steps,loop_s,timesteps_per_s" >"${OUT}"
for BENCH in lj eam chain rhodo; do
    for R in 1 2 4; do
        NAME="${BENCH}-x${R}"
        log "--- Running bench/${INPUT[${BENCH}]}, ${R}x${R}x${R} ---"
        "${LMP}" "${KK_ARGS[@]}" -var x "${R}" -var y "${R}" -var z "${R}" \
            -in "${INPUT[${BENCH}]}" -log "bench-${NAME}.log" \
            >"bench-${NAME}.screen.log" 2>&1
        grep -E '^(Loop time of|Performance:)' "bench-${NAME}.log"
        grep -m1 -F "${STYLE[${BENCH}]}" "bench-${NAME}.log"
        sed -nE 's/^Loop time of ([0-9.e+-]+) on [0-9]+ procs for ([0-9]+) steps with ([0-9]+) atoms.*/\1 \2 \3/p' \
            "bench-${NAME}.log" | while read -r t steps atoms; do
            echo "${BENCH},${R},${atoms},${steps},${t},$(python3 -c "print(${steps} / ${t})")"
        done >>"${OUT}"
    done
done
cat "${OUT}"
[[ "$(wc -l <"${OUT}")" -eq 13 ]]
