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

# When comparing with hip we should use -pme cpu -bonded cpu -update cpu
gmx mdrun -s "benchMEM.tpr" -v -ntmpi 1 -nb gpu
