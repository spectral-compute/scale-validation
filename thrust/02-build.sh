#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh
raise_error_if_using_rocm

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
