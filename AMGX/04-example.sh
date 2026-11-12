#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh

MPI_PATH="$(realpath ../openmpi/install)"

export PATH="${MPI_PATH}/bin:${CUDA_DIR}/bin:${PATH}"
export LD_LIBRARY_PATH="${MPI_PATH}/lib:${LD_LIBRARY_PATH}"
export OMPI_MCA_accelerator=cuda

for MODE in dFFI dDDI; do
    echo -e "\x1b[34;1mVariant\x1b[m: \x1b[1m${MODE}\x1b[m"
    build/examples/amgx_capi \
        -m "AMGX/examples/matrix.mtx" \
        -c "AMGX/src/configs/FGMRES_AGGREGATION.json" \
        -mode "${MODE}"

    echo -e "\x1b[34;1mVariant\x1b[m: \x1b[1m${MODE} with MPI\x1b[m"
    # 02-build.sh builds the MPI examples only where it found P2P support.
    if [ ! -e build/examples/amgx_mpi_capi ]; then
        echo "Skipping due to lack of P2P support"
        continue
    fi
    mpirun -np 2 \
        build/examples/amgx_mpi_capi \
        -m "AMGX/examples/matrix.mtx" \
        -c "AMGX/src/configs/FGMRES_AGGREGATION.json" \
        -mode "${MODE}"
done
