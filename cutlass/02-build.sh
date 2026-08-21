#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh

# We don't support the warpgroup stuff yet.
export SCALE_CUDA_VERSION="11.8"

args=(
    -DCMAKE_BUILD_TYPE=Release
    -DCUTLASS_NVCC_ARCHS="${CUDAARCHS}"
    -DCMAKE_CUDA_ARCHITECTURES="${CUDAARCHS}"
    -DCMAKE_CUDA_COMPILER="nvcc"
    -DCMAKE_CUDA_FLAGS="-Wno-unused-result -Wno-deprecated-declarations"

    -DCUTLASS_TEST_UNIT_ENABLE_WARNINGS=ON
)

# SCALE on AMD uses compiler support for some host FP16 stuff.
if [ "$(basename "$(realpath "$(which nvcc)")")" == "clang" ]; then
    args+=(
        "-DCMAKE_C_COMPILER=$(realpath "$(which nvcc)")"
        "-DCMAKE_CXX_COMPILER=$(realpath "$(which nvcc)")++"
    )
fi

cmake \
    "${args[@]}" \
    -B"build" \
    "cutlass"

make -O -C "build" -j"$(nproc)"
