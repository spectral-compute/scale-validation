#!/bin/bash

set -e
SCRIPT_DIR="$(realpath "$(dirname "$0")")"
source "${SCRIPT_DIR}"/../util/args.sh "$@"

rm -Rf "${OUT_DIR}/cycles/build"
mkdir -p "${OUT_DIR}/cycles/build"

# Cycles's finder script for Glog can't cope with either Arch or Ubuntu.
if cat /etc/issue | grep -F 'Arch Linux' ; then
    CMAKE_EXTRA_ARGS=(-DGLOG_LIBRARY=/usr/lib/libglog.so)
elif cat /etc/issue | grep -F 'Ubuntu' ; then
    CMAKE_EXTRA_ARGS=(-DGLOG_LIBRARY="${SCRIPT_DIR}/libglog_ubuntu.a")
else
    CMAKE_EXTRA_ARGS=()
fi

# Configure.
cmake \
    -DCMAKE_BUILD_TYPE=Release \
    -DWITH_CYCLES_DEVICE_CUDA=ON \
    -DWITH_CYCLES_CUDA_BINARIES=ON \
    -DCYCLES_CUDA_BINARIES_ARCH="${GPU_ARCH}" \
    -DWITH_CYCLES_DEVICE_HIP=OFF \
    -DWITH_CYCLES_HIP_BINARIES=ON \
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
    -DWITH_CYCLES_OPENCOLORIO=OFF \
    "${CMAKE_EXTRA_ARGS[@]}" \
    -DCUDA_TOOLKIT_ROOT_DIR="${CUDA_DIR}" \
    -DCMAKE_INSTALL_PREFIX="${OUT_DIR}/cycles/install" \
    -B"${OUT_DIR}/cycles/build" \
    "${OUT_DIR}/cycles/cycles"

# Make sure we actually found CUDA.
"${SCRIPT_DIR}"/../util/check-cmake-cuda-version.sh "${OUT_DIR}/cycles/build"

# Build.
if [ "${VERBOSE}" == "1" ] ; then
    VERBOSE="VERBOSE=1"
else
    VERBOSE=
fi
make -C "${OUT_DIR}/cycles/build" install -j"${BUILD_JOBS}" ${VERBOSE}
