#!/bin/bash

set -e

cd "UppASD/benchmarks/bccFe"
# The full set is 10 20 30 40 50 60, but we don't want to run a full benchmark
for nx in 10 20 30
do
    # MC GPU
    mkdir MCGPUN$nx/ 2>/dev/null
    echo "NX: " $nx
    cp Base/* MCGPUN$nx/
    cd MCGPUN$nx
    sed -i "s/NX/$nx/g" inpsd.dat
    sed -i "s/NY/$nx/g" inpsd.dat
    sed -i "s/NZ/$nx/g" inpsd.dat
    sed -i "s/MODE/M/g" inpsd.dat
    sed -i "s/nstep/mcnstep/g" inpsd.dat
    sed -i "s/GPU/1/g" inpsd.dat
    time ../../../bin/sd.f95.cuda > out.log
    cd ..
done
exit
