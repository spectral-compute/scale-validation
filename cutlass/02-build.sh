#!/bin/bash

set -ETeuo pipefail

# We don't support the warpgroup stuff yet.
export SCALE_CUDA_VERSION="11.8"

# SCALE on AMD uses compiler support for some host FP16 stuff.
EXTRA_CMAKE_ARGS=()
if [ "$(basename "$(realpath "$(which nvcc)")")" == "clang" ] ; then
    EXTRA_CMAKE_ARGS+=(
        "-DCMAKE_C_COMPILER=$(realpath "$(which nvcc)")"
        "-DCMAKE_CXX_COMPILER=$(realpath "$(which nvcc)")++"
    )
fi

# Configure.
cmake \
    -DCMAKE_BUILD_TYPE=Release \
    -DCUTLASS_NVCC_ARCHS="${CUDAARCHS}" \
    -DCUTLASS_TEST_UNIT_ENABLE_WARNINGS=ON \
    -DCMAKE_CUDA_ARCHITECTURES="${CUDAARCHS}" \
    -DCMAKE_CUDA_COMPILER="nvcc" \
    -DCMAKE_CUDA_FLAGS="-Wno-unused-result -Wno-deprecated-declarations" \
    "${EXTRA_CMAKE_ARGS[@]}" \
    -B"build" \
    "cutlass"

# Build.
make -O -C "build" -j"$(nproc)"
