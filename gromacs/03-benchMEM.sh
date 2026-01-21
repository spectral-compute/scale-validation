#!/bin/bash

# Download the benchmark data if it doesn't already exist.
mkdir -p "data/MaxPlanckInstituteGromacsBenchmarks"
cd "data/MaxPlanckInstituteGromacsBenchmarks"
if [ ! -e benchMEM.zip ] ; then
    wget https://www.mpinat.mpg.de/benchMEM.zip
fi

# Create somewhere for results.
RESULT_FILE="$(pwd)/$(basename -s .sh "$0").csv"
rm -f "${RESULT_FILE}"

RESULT_DIR="$(pwd)/benchmarks/MaxPlanckInstitute/benchMEM"
mkdir -p "${RESULT_DIR}"

cd "${RESULT_DIR}"
if [ ! -e benchMEM.tpr ] ; then
    unzip "data/MaxPlanckInstituteGromacsBenchmarks/benchMEM.zip"
fi
source "${OUT_DIR}/gromacs/install/bin/GMXRC"
set +e
# When comparing with hip we should use -pme cpu -bonded cpu -update cpu
#gmx mdrun -s benchMEM.tpr -v -ntmpi 1 -pme cpu -bonded cpu -update cpu -nb gpu
# When comparing with a more complete version
gmx mdrun -s benchMEM.tpr -v -ntmpi 1 -nb gpu
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
