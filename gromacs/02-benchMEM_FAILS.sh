#!/bin/bash

echo "benchMem fails!! "
source "$(dirname "$0")"/../util/args.sh "$@"
export LD_LIBRARY_PATH="${CUDA_DIR}/lib"

# Download the benchmark data if it doesn't already exist.
mkdir -p "${OUT_DIR}/data/MaxPlanckInstituteGromacsBenchmarks"
cd "${OUT_DIR}/data/MaxPlanckInstituteGromacsBenchmarks"
wget -q https://www.mpinat.mpg.de/benchMEM.zip

# Create somewhere for results.
RESULT_FILE="${OUT_DIR}/gromacs/$(basename -s .sh "$0").csv"
rm -f "${RESULT_FILE}"

RESULT_DIR="${OUT_DIR}/gromacs/benchmarks/MaxPlanckInstitute"
mkdir -p "${RESULT_DIR}"

source "${OUT_DIR}/gromacs/install/bin/GMXRC"
unzip benchMEM.zip
#gmx mdrun -s 
gmx mdrun -s benchMEM.tpr -nb gpu 
echo "Done"
