#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh
raise_error_if_using_rocm

MPI_DIR="$(realpath ../)/openmpi/install"
if [ ! -e "${MPI_DIR}" ] ; then
    echo "Please build the OpenMPI third party project first. Use the same working directory." 1>&2
    exit 1
fi

cmake \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX=install \
    -DMPI_HOME=${MPI_DIR} \
    -DBUILD_MPI=yes \
    -DPKG_SNAP=yes \
    -DPKG_GPU=no \
    -DPKG_KOKKOS=yes \
    -DPKG_ML-SNAP=ON \
    -DKokkos_ENABLE_CUDA=ON \
    -DKokkos_ARCH_AMPERE86=ON \
    -DCMAKE_CXX_COMPILER=clang++ \
    -B"build" \
    "lammps/cmake"

make -O -C "build" -j"$(nproc)"
