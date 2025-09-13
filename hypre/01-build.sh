#!/bin/bash

SCRIPT_DIR="$(realpath "$(dirname "$0")")"
source "${SCRIPT_DIR}"/../util/args.sh "$@"

MPI_DIR="${OUT_DIR}/openmpi/install"
if [ ! -e "${MPI_DIR}" ] ; then
    echo "Please build the OpenMPI third party project first. Use the same working directory." 1>&2
    exit 1
fi

# Clean up any previous stuff.
rm -rf "${OUT_DIR}/hypre/build"

# Copy the source tree for in-tree build because the cmake build system builds fewer tests.
cp -r "${OUT_DIR}/hypre/hypre" "${OUT_DIR}/hypre/build"

# Configure
SM="$(echo "${GPU_ARCH}" | sed -E 's/sm_//g')"

cd "${OUT_DIR}/hypre/build/src"
./configure \
  --enable-unified-memory \
  --with-cuda \
  --with-gpu-arch="${SM}" \
  --disable-onemklsparse \
  --disable-onemklblas \
  --disable-onemklrand \
  --with-MPI-include="${MPI_DIR}/include" \
  --with-MPI-libs="mpi" \
  --with-MPI-lib-dirs="${MPI_DIR}/lib" \

make test -j$(nproc)
