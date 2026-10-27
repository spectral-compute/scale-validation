#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh

MPI_DIR="$(realpath ../)/openmpi/install"
if [ ! -e "${MPI_DIR}" ]; then
    echo "Please build the OpenMPI third party project first. Use the same working directory." 1>&2
    exit 1
fi

# hypre's configure only looks for MPI compiler wrappers (mpicc, ...) and
# doesn't fall back to cc, so use the ones from our OpenMPI.
export PATH="${MPI_DIR}/bin:${PATH}"
export LD_LIBRARY_PATH="${MPI_DIR}/lib:${LD_LIBRARY_PATH:-}"

# In-tree build, because the CMake build system builds fewer of the test drivers.
# The build only needs src/, so leave .git out of the copy. Start from a fresh
# copy each time, since `cp -r` into an existing directory would nest it.
rm -rf build
mkdir build
cp -r hypre/src build/src

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
# For experiments, e.g. HYPRE_EXTRA_CONFIGURE_ARGS="--disable-cusparse".
# shellcheck disable=2206
args+=(${HYPRE_EXTRA_CONFIGURE_ARGS:-})

(
    cd "build/src"
    ./configure "${args[@]}"
    make test -j"$(nproc)" -O
)
