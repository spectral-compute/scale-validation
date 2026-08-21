#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh

export VCPKG_KEEP_ENV_VARS=CMAKE_POLICY_VERSION_MINIMUM
export CMAKE_POLICY_VERSION_MINIMUM=3.5

# Configure.
args=(
    -DCMAKE_CUDA_ARCHITECTURES="${CUDAARCHS}"
    -DCMAKE_CUDA_COMPILER="nvcc"

    # Disable some warnings which alien triggers
    -DCMAKE_CXX_FLAGS="-Wno-stringop-overread -Wno-format-truncation -Wno-format -Wno-switch"
    -DCMAKE_CUDA_FLAGS="-Wno-format -Wno-switch"

    -DCMAKE_BUILD_TYPE=Release
)

cmake \
    "${args[@]}" \
    -B"build" \
    "alien"

# Build.
make -O -C "build" -j"$(nproc)"
