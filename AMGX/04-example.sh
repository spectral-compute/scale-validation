#!/bin/bash

set -e

MPI_PATH=$(realpath ../openmpi/install)
SRC_DIR=$(realpath ./AMGX)

export PATH="${MPI_PATH}/bin:${CUDA_DIR}/bin:${PATH}"
export LD_LIBRARY_PATH="${MPI_PATH}/lib:${LD_LIBRARY_PATH}"
export OMPI_MCA_accelerator=cuda

for MODE in dFFI dDDI ; do
    echo -e "\x1b[34;1mVariant\x1b[m: \x1b[1m${MODE}\x1b[m"
    build/examples/amgx_capi \
        -m ${SRC_DIR}/examples/matrix.mtx \
        -c ${SRC_DIR}/src/configs/FGMRES_AGGREGATION.json \
        -mode ${MODE}

    echo -e "\x1b[34;1mVariant\x1b[m: \x1b[1m${MODE} with MPI\x1b[m"
    if [ ! -z "$(which scalediag)" ] && ! scalediag full-driver p2p ; then
        echo "Skipping due to lack of support"
        continue
    fi
    mpirun -np 2 \
        build/examples/amgx_mpi_capi \
        -m ${SRC_DIR}/examples/matrix.mtx \
        -c ${SRC_DIR}/src/configs/FGMRES_AGGREGATION.json \
        -mode ${MODE}
done
