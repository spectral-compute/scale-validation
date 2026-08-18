#!/bin/bash

set -eo pipefail

# Download the benchmark data if it doesn't already exist.
BENCH_MEM="data/MaxPlanckInstituteGromacsBenchmarks"
mkdir -p "$BENCH_MEM"
if [ ! -e "$BENCH_MEM/benchMEM.zip" ] ; then
    wget https://data.spectralcompute.co.uk/gromacs/benchMEM.zip -O "$BENCH_MEM/benchMEM.zip"
    unzip "$BENCH_MEM/benchMEM.zip"
fi

source "install/bin/GMXRC"

# If trying to compare with the HIP build of GROMACS, you may consider using:
#   -pme cpu -bonded cpu -update cpu
# This is because the HIP version of GROMACS doesn't perform those types of calculations
# on the GPU, but the CUDA version does.
# So, adding those arguments gives a closer comparison of what we're actually running on the GPU
# If GROMACS is your workload and you just want to know which is faster, you may wish to leave it out.
echo "Running only benchMEM"
time gmx mdrun -s "benchMEM.tpr" -v -ntmpi 1 -nb gpu
