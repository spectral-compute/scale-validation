#!/usr/bin/env bash
#
# Configure and build code_saturne's CUDA backend, against the openmpi project's
# Open MPI and the mesh libraries from 02-build-deps.sh.
. "$(dirname "$0")"/../util/prelude.sh
. "$(dirname "$0")"/common.bash

use_openmpi

# The GUI's Python dependencies (requirements.txt), in a venv that lives in the
# workdir. configure records this venv's python for the code_saturne launcher.
uv venv --clear venv
# shellcheck disable=SC1091
. venv/bin/activate
uv pip install -r "${SCRIPT_DIR}/requirements.txt"

# 01-patch.sh has switched on automake's test harness in tests/Makefile.am,
# which upstream ships disabled; autoreconf has to run after that for it to
# reach the generated Makefile. 04-test.sh then just runs "make check".
(cd code_saturne && autoreconf -i)

# cs_mpi.m4 takes -I/-L from --with-mpi's prefix, identifies OpenMPI by
# OMPI_MAJOR_VERSION in mpi.h and then links -lmpi, so plain compilers work --
# no mpicc wrapper needed. The rpaths save every later script from having to
# re-export LD_LIBRARY_PATH just to load libmpi and the mesh libraries.
ldflags="-Wl,-rpath,${OPENMPI_INSTALL}/lib -Wl,-rpath,${DEPS_INSTALL}/lib"
if [[ -n "${SCALE_ENV:-}" ]]; then
    ldflags="-L/opt/rocm-scale/lib -lhsa-runtime64 ${ldflags}"
fi

configure_args=(
    --prefix="${CS_INSTALL}"
    --with-mpi="${OPENMPI_INSTALL}"
    --enable-cuda
    --without-cusparse
    --with-hdf5="${DEPS_INSTALL}"
    --with-med="${DEPS_INSTALL}"
    --with-cgns="${DEPS_INSTALL}"
)

rm -rf code_saturne/build
mkdir -p code_saturne/build
cd code_saturne/build

# code_saturne takes its GPU arch from CUDA_ARCH_NUM, not CMake's CUDAARCHS.
# The fallback of 75 only applies standalone; test.sh always sets CUDAARCHS.
LDFLAGS="${ldflags}" CUDA_ARCH_NUM="${CUDAARCHS:-75}" ../configure "${configure_args[@]}"

make -j"$(nproc)"
make install
