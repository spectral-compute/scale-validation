#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh

OUT_DIR=$(realpath ../)

mkdir build
cd build

# Create a pkgconfig file. Normally, this would be provided by the OS, but since we don't know where the SCALE package
# is going to be installed to (e.g: in the case of the tarball, or during development, or whatever), we can't just
# distribute one in all cases.
mkdir -p "${OUT_DIR}/openmpi/lib/pkgconfig"
cat >"${OUT_DIR}/openmpi/lib/pkgconfig/cuda.pc" <<EOF
cudaroot="${CUDA_PATH}"
libdir=\${cudaroot}/lib
includedir=\${cudaroot}/include

Name: cuda
Description: SCALE or CUDA
Version: 12.5
Libs: -L\${libdir} -lcuda
Cflags: -I\${includedir}
EOF

args=(
    --with-cuda="${CUDA_PATH}"
    --with-cuda-libdir="${OUT_DIR}/openmpi/lib"
    --prefix "${OUT_DIR}/openmpi/install"

    --enable-mca-dso="accelerator_cuda,btl_smcuda"
)

../source/configure "${args[@]}"
