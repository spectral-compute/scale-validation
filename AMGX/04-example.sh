#!/bin/bash

set -e
source "$(dirname "$0")"/../util/args.sh "$@"
cd "${OUT_DIR}/AMGX/AMGX/build"

export PATH="${OUT_DIR}/openmpi/install/bin:${CUDA_DIR}/bin:${PATH}"
export LD_LIBRARY_PATH="${OUT_DIR}/openmpi/install/lib:${LD_LIBRARY_PATH}"
export OMPI_MCA_accelerator=cuda

for MODE in dFFI dDDI ; do
    echo -e "\x1b[34;1mVariant\x1b[m: \x1b[1m${MODE}\x1b[m"
    examples/amgx_capi -m ../examples/matrix.mtx -c ../src/configs/FGMRES_AGGREGATION.json -mode ${MODE}

    echo -e "\x1b[34;1mVariant\x1b[m: \x1b[1m${MODE} with MPI\x1b[m"
    if [ ! -z "$(which scalediag)" ] && ! scalediag full-driver p2p ; then
        echo "Skipping due to lack of support"
        continue
    fi
    mpirun -np 2 \
        examples/amgx_mpi_capi -m ../examples/matrix.mtx -c ../src/configs/FGMRES_AGGREGATION.json -mode ${MODE}
done
