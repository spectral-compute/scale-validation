#!/usr/bin/env bash
# shellcheck source-path=SCRIPTDIR
. "$(dirname "$0")"/../../util/prelude.sh

# Cycles' own HIP backend, as the native baseline. Same options as ../02-build.sh with CUDA swapped
# for HIP (no HIP RT, matching the BVH2 traversal the CUDA build uses without OptiX).

# Standalone Cycles' hipew only looks for libamdhip64.so.6; ROCm 7 ships .so.7. Blender's copy of
# hipew already searches for both.
git -C cycles apply "${SCRIPT_DIR}/hipew-rocm7.patch"

args=(
    -DCMAKE_BUILD_TYPE=Release
    -DCMAKE_INSTALL_PREFIX="install"
    -DWITH_STRICT_BUILD_OPTIONS=ON

    -DWITH_CYCLES_DEVICE_CUDA=OFF
    -DWITH_CYCLES_CUDA_BINARIES=OFF
    -DWITH_CYCLES_DEVICE_OPTIX=OFF

    -DWITH_CYCLES_DEVICE_HIP=ON
    -DWITH_CYCLES_HIP_BINARIES=ON
    -DCYCLES_HIP_BINARIES_ARCH="${TEST_GPU_ARCH}"
    -DWITH_CYCLES_DEVICE_HIPRT=OFF
    -DHIP_ROOT_DIR="${ROCM_PATH}"

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

if echo "$(
    source /etc/os-release
    echo "$NAME"
)" | grep -F 'Arch Linux'; then
    args+=(-DGLOG_LIBRARY=/usr/lib/libglog.so)
elif grep -qF 'Ubuntu' /etc/issue; then
    args+=(-DGLOG_LIBRARY="$(realpath "${SCRIPT_DIR}/..")/libglog_ubuntu.a")
fi

cmake \
    "${args[@]}" \
    -B"build" \
    "cycles"

make -O -C "build" install -j"$(nproc)"
