#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh

INSTALL_PREFIX="$(pwd)/install"

# Install nv-codec-headers so FFmpeg can find NVENC/NVDEC/CUVID.
make -C nv-codec-headers PREFIX="${INSTALL_PREFIX}" install

export PKG_CONFIG_PATH="${INSTALL_PREFIX}/lib/pkgconfig${PKG_CONFIG_PATH:+:$PKG_CONFIG_PATH}"

# Configure with CUDA/NVENC/NVDEC support.
cd ffmpeg &&
    ./configure \
        --prefix="${INSTALL_PREFIX}" \
        --enable-nonfree \
        --disable-x86asm \
        --enable-filter=scale_cuda \
        --enable-cuda-nvcc \
        --nvccflags="-gencode arch=compute_$CUDAARCHS,code=sm_$CUDAARCHS -O2"

make -O -C ffmpeg -j"$(nproc)"
make -O -C ffmpeg -j"$(nproc)" install
