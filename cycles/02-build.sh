#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh

args=(
    -DCMAKE_BUILD_TYPE=Release
    -DCMAKE_INSTALL_PREFIX="install"
    -DWITH_STRICT_BUILD_OPTIONS=ON

    -DWITH_CYCLES_DEVICE_CUDA=ON
    -DWITH_CYCLES_CUDA_BINARIES=ON
    -DCYCLES_CUDA_BINARIES_ARCH="${GPU_ARCH}"

    -DWITH_CYCLES_DEVICE_HIP=OFF
    -DWITH_CYCLES_HIP_BINARIES=OFF
    -DWITH_CYCLES_DEVICE_OPTIX=OFF

    -DGLOG_INCLUDE_DIR=/usr/include

    -DWITH_CYCLES_LOGGING=ON
    -DWITH_CYCLES_OPENCOLORIO=ON
    -DWITH_CYCLES_HYDRA_RENDER_DELEGATE=OFF
    -DWITH_CYCLES_NANOVDB=OFF
    -DWITH_CYCLES_ALEMBIC=OFF
    -DWITH_CYCLES_OPENVDB=OFF
    -DWITH_CYCLES_USD=OFF
    -DWITH_CYCLES_OSL=OFF
)

# Cycles's finder script for Glog can't cope with either Arch or Ubuntu.
# TODO: Sketchy. Internal issue #1200
if echo "$(
    source /etc/os-release
    echo "$NAME"
)" | grep -F 'Arch Linux'; then
    log "Forcibly using system libglog"
    args+=(-DGLOG_LIBRARY=/usr/lib/libglog.so)
elif cat /etc/issue | grep -F 'Ubuntu'; then
    log "Forcibly using vendored libglog"
    args+=(-DGLOG_LIBRARY="$(realpath "$(dirname "$0")")/libglog_ubuntu.a")
fi

# On NVIDIA targets, ${CUDA_PATH} (scaleenv's "Using cuda install at ..." pick) might be a runtime-only install.
# In this case, `find_package(CUDA)` can't see a full toolkit (missing CUDA_INCLUDE_DIRS/CUDA_CUDART_LIBRARY)
# This is only a problem because cyclces calls that explicitly, rather than inferring the cuda toolkit based off of where nvcc is.
# In these cases, explicitly tell cmake where cuda is, bypassing this overly-strict check.
if [[ "${GPU_ARCH}" != sm_* ]]; then
    args+=(-DCUDA_TOOLKIT_ROOT_DIR="${CUDA_PATH}")
fi

cmake \
    "${args[@]}" \
    -B"build" \
    "cycles"

make -O -C "build" install -j"$(nproc)"
