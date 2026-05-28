#!/bin/bash

set -e

OUT_DIR=$(realpath ../)
if [ ! -e "${OUT_DIR}/openmpi/install" ] ; then
    echo "Please build the OpenMPI third party project first. Use the same working directory." 1>&2
    exit 1
fi

cmake \
  -D MPI_HOME=${OUT_DIR}/openmpi/install \
  -D BUILD_TESTING=OFF \
  -D CMAKE_BUILD_TYPE=Release \
  -D CMAKE_CXX_COMPILER=clang++ \
  -D CMAKE_CUDA_COMPILER=clang++ \
  -D CMAKE_CXX_STANDARD=20 \
  -D Kokkos_ARCH_AMPERE86=ON \
  -D Kokkos_ENABLE_CUDA=ON \
  -D Novapp_EOS=PerfectGas \
  -D Novapp_GEOM=Cartesian \
  -D Novapp_GRAVITY=Uniform \
  -D Novapp_NDIM=3 \
  -D Novapp_SETUP=rayleigh_taylor3d \
  -D Novapp_inih_DEPENDENCY_POLICY=EMBEDDED \
  -D Novapp_Kokkos_DEPENDENCY_POLICY=EMBEDDED \
  -B build \
  "heraclespp"

make -O -C "build" -j"$(nproc)"
