#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh

# Configure.
args=(
    -DCMAKE_BUILD_TYPE=Release
    -DCMAKE_CUDA_COMPILER="nvcc"
    -DCMAKE_INSTALL_PREFIX="install"

    -DTHRUST_DISABLE_ARCH_BY_DEFAULT=On
    "-DTHRUST_ENABLE_COMPUTE_${CUDAARCHS}=On"
)
cmake \
    "${args[@]}" \
    -B"build" \
    "thrust"

# Build.
cmake --build "build" -j"$(nproc)"
