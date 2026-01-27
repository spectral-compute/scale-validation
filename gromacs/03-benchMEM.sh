#!/bin/bash

# set -ETeuo pipefail
# set -o xtrace

# Download the benchmark data if it doesn't already exist.
BENCH_MEM="data/MaxPlanckInstituteGromacsBenchmarks"
mkdir -p "$BENCH_MEM"
if [ ! -e "$BENCH_MEM/benchMEM.zip" ] ; then
    wget https://www.mpinat.mpg.de/benchMEM.zip -O "$BENCH_MEM/benchMEM.zip"
    unzip "$BENCH_MEM/benchMEM.zip"
fi

# Create somewhere for results.
RESULT_FILE="$(pwd)/$(basename -s .sh "$0").csv"
rm -f "${RESULT_FILE}"

RESULT_DIR="$(pwd)/benchmarks/MaxPlanckInstitute/benchMEM"
mkdir -p "${RESULT_DIR}"

source "install/bin/GMXRC"

set +e
# When comparing with hip we should use -pme cpu -bonded cpu -update cpu
#gmx mdrun -s benchMEM.tpr -v -ntmpi 1 -pme cpu -bonded cpu -update cpu -nb gpu
# When comparing with a more complete version
gmx mdrun -s "benchMEM.tpr" -v -ntmpi 1 -nb gpu
RESULT=$?
set -e
# Log to result CSV
if [ "$RESULT" != 0 ]; then
    echo "MPGbenchMEM,status,fail" >> "${RESULT_FILE}"
else
    echo "MPGbenchMEM,status,success" >> "${RESULT_FILE}"
    echo "MPGbenchMEM,time,$(grep 'Time:' md.log | sed -E 's/ +/ /g' | cut -d ' ' -f 4)" >> "${RESULT_FILE}"
fi

# Pretty print result
sed -E 's/(.*),status,(.*)/\1: \2/;s/(.*),time,(.*)/\1: \2 s/' "${RESULT_FILE}"

echo "Done"
