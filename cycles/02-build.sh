#!/bin/bash

set -e

# Cycles's finder script for Glog can't cope with either Arch or Ubuntu.
# TODO: This is pretty scuffed
if echo $(source /etc/os-release ; echo $NAME) | grep -F 'Arch Linux' ; then
    CMAKE_EXTRA_ARGS=(-DGLOG_LIBRARY=/usr/lib/libglog.so)
elif cat /etc/issue | grep -F 'Ubuntu' ; then
    CMAKE_EXTRA_ARGS=(-DGLOG_LIBRARY="$(realpath "$(dirname "$0")")/libglog_ubuntu.a")
else
    CMAKE_EXTRA_ARGS=()
fi

# On real NVIDIA targets, ${CUDA_PATH} (scaleenv's "Using cuda install at ..." pick) is a
# runtime-only install that legacy find_package(CUDA) can't see a full toolkit under
# (missing CUDA_INCLUDE_DIRS/CUDA_CUDART_LIBRARY) -- same environment whispercpp builds
# against successfully by never hinting a root at all and letting CMake resolve nvcc (and
# from it, the toolkit root) via $PATH instead. Only skip the hint for sm_* GPU_ARCH so
# the AMD path (which works today with this hint) is untouched.
if [[ "${GPU_ARCH}" != sm_* ]] ; then
    CMAKE_EXTRA_ARGS+=(-DCUDA_TOOLKIT_ROOT_DIR="${CUDA_PATH}")
fi

# Configure.
cmake \
    -DCMAKE_BUILD_TYPE=Release \
    -DWITH_CYCLES_DEVICE_CUDA=ON \
    -DWITH_CYCLES_CUDA_BINARIES=ON \
    -DCYCLES_CUDA_BINARIES_ARCH="${GPU_ARCH}" \
    -DWITH_CYCLES_DEVICE_HIP=OFF \
    -DWITH_CYCLES_HIP_BINARIES=OFF \
    -DWITH_CYCLES_DEVICE_OPTIX=OFF \
    -DWITH_STRICT_BUILD_OPTIONS=ON \
    -DWITH_CYCLES_USD=OFF \
    -DWITH_CYCLES_OSL=OFF \
    -DGLOG_INCLUDE_DIR=/usr/include \
    -DWITH_CYCLES_LOGGING=ON \
    -DWITH_CYCLES_HYDRA_RENDER_DELEGATE=OFF \
    -DWITH_CYCLES_NANOVDB=OFF \
    -DWITH_CYCLES_ALEMBIC=OFF \
    -DWITH_CYCLES_OPENVDB=OFF \
    -DWITH_CYCLES_OPENCOLORIO=ON \
    "${CMAKE_EXTRA_ARGS[@]}" \
    -DCMAKE_INSTALL_PREFIX="install" \
    -B"build" \
    "cycles"

make -O -C "build" install -j"$(nproc)"
