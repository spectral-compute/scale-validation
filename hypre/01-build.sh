#!/bin/bash

MPI_DIR="$(realpath ../)/openmpi/install"
if [ ! -e "${MPI_DIR}" ] ; then
    echo "Please build the OpenMPI third party project first. Use the same working directory." 1>&2
    exit 1
fi

# Copy the source tree for in-tree build because the cmake build system builds fewer tests.
cp -r "hypre" "build"

# Configure

cd "build/src"
./configure \
  --enable-unified-memory \
  --with-cuda \
  --with-gpu-arch="${SCALE_FAKE_CUDA_ARCH}" \
  --disable-onemklsparse \
  --disable-onemklblas \
  --disable-onemklrand \
  --with-MPI-include="${MPI_DIR}/include" \
  --with-MPI-libs="mpi" \
  --with-MPI-lib-dirs="${MPI_DIR}/lib" \

make test -j$(nproc)
