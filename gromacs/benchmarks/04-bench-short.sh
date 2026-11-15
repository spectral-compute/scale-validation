#!/usr/bin/env bash
# shellcheck source-path=SCRIPTDIR
. "$(dirname "$0")"/../../util/prelude.sh

# benchMEM (82k atoms) in two modes:
#  - default: whatever each build offloads by itself. The CUDA build also puts
#    PME, bonded and update on the GPU; the HIP build doesn't.
#  - gpu-nb-only: -pme cpu -bonded cpu -update cpu, so both run the same work
#    on the GPU. Note the builds have OpenMP off, so the CPU side is 1 thread.
BENCH_MEM="data/MaxPlanckInstituteGromacsBenchmarks"
mkdir -p "$BENCH_MEM"
if [ ! -e "$BENCH_MEM/benchMEM.zip" ]; then
    wget -nv https://data.spectralcompute.co.uk/gromacs/benchMEM.zip \
        -O "$BENCH_MEM/benchMEM.zip"
    unzip -o "$BENCH_MEM/benchMEM.zip"
fi
OUT="${RESULTS_DIR:-$(realpath .)}/gromacs.${BENCHMARK_COMPILER:-unknown}"
OUT+=".${TEST_GPU_ARCH}.$(date -u +%Y%m%d%H%M%S).csv"
TPR="$(realpath benchMEM.tpr)"

# GMXRC doesn't like the strict error flags we use in our scripts
set +ETeuo pipefail
source "install/bin/GMXRC"
set -ETeuo pipefail

echo "case,mode,ns_per_day,wall_s" >"${OUT}"
for MODE in default gpu-nb-only; do
    EXTRA=()
    if [[ "${MODE}" == gpu-nb-only ]]; then
        EXTRA=(-pme cpu -bonded cpu -update cpu)
    fi
    rm -rf "run-${MODE}" && mkdir "run-${MODE}"
    (
        cd "run-${MODE}"
        log "Running benchMEM, mode ${MODE}: ${EXTRA[*]}"
        gmx mdrun -s "${TPR}" -ntmpi 1 -nb gpu -resethway -noconfout \
            "${EXTRA[@]}"
        grep -E '^(Performance:|\s+Time:)' md.log
        nsday="$(awk '/^Performance:/ {print $2}' md.log)"
        wall="$(awk '/^ +Time:/ {print $3}' md.log)"
        echo "benchMEM,${MODE},${nsday},${wall}" >>"${OUT}"
    )
done
cat "${OUT}"
[[ "$(wc -l <"${OUT}")" -eq 3 ]]
