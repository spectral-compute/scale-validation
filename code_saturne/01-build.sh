#!/bin/bash
#
# Build and install code_saturne with CUDA enabled. Run after 00-clone.sh
# from the same working directory.
#
# System prerequisites (Ubuntu 24.04):
#   sudo apt-get install -y autoconf automake libtool openmpi-bin libopenmpi-dev python3-dev

set -ETeuo pipefail

cs_install_dir="$(realpath code_saturne-install)"

# Ubuntu's split multiarch layout puts the MPI installation root under a
# non-standard prefix; ompi_info gives us the exact path regardless of distro.
if ! command -v ompi_info > /dev/null 2>&1; then
  echo "ompi_info not found: install openmpi-bin (e.g. apt-get install openmpi-bin libopenmpi-dev)" >&2
  exit 1
fi
mpi_dir="$(dirname "$(ompi_info --path libdir | awk '{print $NF}')")"

# code_saturne uses CUDA_ARCH_NUM, not CMake's CUDAARCHS. The fallback of 75
# only applies standalone; test.sh always sets CUDAARCHS via scaleenv.
cuda_arch_num="${CUDAARCHS:-75}"

(
  cd code_saturne
  ./sbin/bootstrap
  CUDA_ARCH_NUM="${cuda_arch_num}" ./configure \
    --with-mpi="${mpi_dir}" \
    --prefix="${cs_install_dir}" \
    --enable-cuda \
    --without-cublas \
    --without-cusparse \
    --without-med \
    --without-cgns \
    --disable-gui
  make -j"$(nproc)"
  make install
)
