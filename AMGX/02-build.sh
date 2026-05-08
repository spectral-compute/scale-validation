#!/bin/bash

set -e

OUT_DIR=$(realpath ../)
if [ ! -e "${OUT_DIR}/openmpi/install" ] ; then
    echo "Please build the OpenMPI third party project first. Use the same working directory." 1>&2
    exit 1
fi

cmake \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_CUDA_COMPILER="nvcc" \
    -DCMAKE_CUDA_ARCHITECTURES="${CUDAARCHS}" \
    -DCUDA_ARCH="${CUDAARCHS}" \
    -DCMAKE_NO_MPI=Off \
    -B"build" \
    "AMGX"

make -O -C "build" -j"$(nproc)"
