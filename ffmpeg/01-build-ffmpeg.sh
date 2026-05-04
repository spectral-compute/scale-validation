#!/bin/bash

set -e

INSTALL_PREFIX="$(pwd)/install"

# Install nv-codec-headers so FFmpeg can find NVENC/NVDEC/CUVID.
make -C nv-codec-headers PREFIX="${INSTALL_PREFIX}" install
export PKG_CONFIG_PATH="${INSTALL_PREFIX}/lib/pkgconfig${PKG_CONFIG_PATH:+:$PKG_CONFIG_PATH}"

cd ffmpeg

# Configure with CUDA/NVENC/NVDEC support.
./configure \
    --prefix="${INSTALL_PREFIX}" \
    --enable-nonfree \
    --disable-x86asm \
    --enable-filter=scale_cuda \
    --enable-cuda-nvcc

make -j"$(nproc)"
make install

cd -
