#!/bin/bash

set -e

OUT_DIR=$(realpath ../)
if [ ! -e "${OUT_DIR}/openmpi/install" ] ; then
    echo "Please build the OpenMPI third party project first. Use the same working directory." 1>&2
    exit 1
fi

# Configure.
if [ -z "$(which scalediag)" ] || scalediag full-driver p2p ; then
    CMAKE_NO_MPI=Off
else
    CMAKE_NO_MPI=On
fi

cmake \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_CUDA_COMPILER="nvcc" \
    -DCMAKE_CUDA_ARCHITECTURES="${CUDAARCHS}" \
    -DCUDA_ARCH="${CUDAARCHS}" \
    -DCMAKE_NO_MPI=${CMAKE_NO_MPI} \
    -B"build" \
    "AMGX"

make -C "build" -j"$(nproc)"
