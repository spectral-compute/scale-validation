#!/bin/bash

source "$(dirname "$0")"/../util/args.sh "$@"
export LD_LIBRARY_PATH="${CUDA_DIR}/lib"

# Download the benchmark data if it doesn't already exist.
mkdir -p "${OUT_DIR}/data/MaxPlanckInstituteGromacsBenchmarks"
cd "${OUT_DIR}/data/MaxPlanckInstituteGromacsBenchmarks"
if [ ! -e benchMEM.zip ] ; then
    wget https://www.mpinat.mpg.de/benchMEM.zip
fi

# Create somewhere for results.
RESULT_FILE="${OUT_DIR}/gromacs/$(basename -s .sh "$0").csv"
rm -f "${RESULT_FILE}"

RESULT_DIR="${OUT_DIR}/gromacs/benchmarks/MaxPlanckInstitute/benchMEM"
mkdir -p "${RESULT_DIR}"
cd "${RESULT_DIR}"
if [ ! -e benchMEM.tpr ] ; then
    unzip "${OUT_DIR}/data/MaxPlanckInstituteGromacsBenchmarks/benchMEM.zip"
fi
source "${OUT_DIR}/gromacs/install/bin/GMXRC"
set +e
gmx mdrun -s benchMEM.tpr -nb gpu -pme cpu 
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
