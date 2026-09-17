#!/bin/bash

set -ETeuo pipefail

# cd $(dirname $0)

cs_install_dir="$(realpath code_saturne-install)"

# HDF5, MED and CGNS, built by 02-build-deps.sh into one prefix. Without them
# the preprocessor cannot read the .med and .cgns meshes the tutorials ship.
deps_install_dir="$(realpath deps-install)"

OUT_DIR=$(realpath ../)
if [ ! -e "${OUT_DIR}/openmpi/install" ] ; then
    echo "Please build the OpenMPI third party project first. Use the same working directory." 1>&2
    exit 1
fi
mpi_dir="${OUT_DIR}/openmpi/install"

# configure probes for mpiexec under --with-mpi's bin, and records the variant
# it finds in the run scripts 05-validate.sh drives.
export PATH="${mpi_dir}/bin:${PATH}"
export LD_LIBRARY_PATH="${mpi_dir}/lib:${LD_LIBRARY_PATH:-}"

# code_saturne uses CUDA_ARCH_NUM, not CMake's CUDAARCHS. The fallback of 75
# only applies standalone; test.sh always sets CUDAARCHS via scaleenv.
cuda_arch_num="${CUDAARCHS:-75}"

test -d code_saturne || {
	rm -rf code_saturne/build
}
cd code_saturne

# 01-patch.sh has switched on automake's test harness in tests/Makefile.am,
# which upstream ships disabled; autoreconf has to run after that for it to
# reach the generated Makefile. 04-test.sh then just runs "make check".
autoreconf -i
mkdir -p build && cd build

dir=$(dirname $0)

uv venv --clear $dir/.venv
source $dir/.venv/bin/activate
uv pip install -r $dir/requirements.txt

# cs_mpi.m4 takes -I/-L from --with-mpi's prefix, identifies OpenMPI by
# OMPI_MAJOR_VERSION in mpi.h and then links -lmpi, so plain compilers work --
# no mpicc wrapper needed. The rpath saves every later script from having to
# re-export LD_LIBRARY_PATH just to load libmpi.
LDFLAGS="-L/opt/rocm-scale/lib -lhsa-runtime64 -Wl,-rpath,${mpi_dir}/lib -Wl,-rpath,${deps_install_dir}/lib" \
CUDA_ARCH_NUM="${cuda_arch_num}" ../configure \
    --with-mpi="${mpi_dir}" \
    --prefix="${cs_install_dir}" \
    --enable-cuda \
    --without-cusparse \
    --with-hdf5="${deps_install_dir}" \
    --with-med="${deps_install_dir}" \
    --with-cgns="${deps_install_dir}"

make -j"$(nproc)"
make install
