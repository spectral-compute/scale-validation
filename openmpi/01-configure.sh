#!/bin/bash

set -e

OUT_DIR=$(realpath ../)

mkdir build
cd build

# Create a pkgconfig file. Normally, this would be provided by the OS, but since we don't know where the SCALE package
# is going to be installed to (e.g: in the case of the tarball, or during development, or whatever), we can't just
# distribute one in all cases.
mkdir -p "${OUT_DIR}/openmpi/lib/pkgconfig"
echo "cudaroot="${CUDA_PATH}"
libdir=\${cudaroot}/lib
includedir=\${cudaroot}/include

Name: cuda
Description: SCALE or CUDA
Version: 12.5
Libs: -L\${libdir} -lcuda
Cflags: -I\${includedir}" > "${OUT_DIR}/openmpi/lib/pkgconfig/cuda.pc"

# --with-pmix/--with-prrte: without these, configure picks up the system PMIx
# (/usr/lib/x86_64-linux-gnu/pmix2) and the prte it launches with then exports
# OMPI_MCA_mca_base_component_path pointing into *that* tree to every rank. That
# overrides Open MPI's own component directory, so no DSO component loads inside
# an MPI process -- including accelerator_cuda. The accelerator framework then
# falls back to "null", every buffer is treated as host memory, and the first
# device pointer handed to MPI_Isend is memcpy'd on the host: SIGSEGV with
# "Invalid permissions" at the device address. Bundling both keeps the component
# path pointing at this install.
../source/configure \
  --prefix "${OUT_DIR}/openmpi/install" \
  --with-pmix=internal \
  --with-prrte=internal \
  --enable-mca-dso=accelerator_cuda,btl_smcuda \
  --with-cuda="${CUDA_PATH}" \
  --with-cuda-libdir="${OUT_DIR}/openmpi/lib"
