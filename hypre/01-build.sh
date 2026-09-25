#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh

MPI_DIR="$(realpath ../)/openmpi/install"
if [ ! -e "${MPI_DIR}" ]; then
    echo "Please build the OpenMPI third party project first. Use the same working directory." 1>&2
    exit 1
fi

cp -r "hypre" "build"

args=(
    --with-cuda
    --with-gpu-arch="${CUDAARCHS}"

    --enable-unified-memory
    --disable-onemklsparse
    --disable-onemklblas
    --disable-onemklrand

    --with-MPI-include="${MPI_DIR}/include"
    --with-MPI-libs="mpi"
    --with-MPI-lib-dirs="${MPI_DIR}/lib"
)

(
    cd "build/src"
    ./configure "${args[@]}"
    make test -j"$(nproc)" -O
)
