#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh
raise_error_if_using_rocm

args=(
    -DCMAKE_BUILD_TYPE=Release
    -DCMAKE_POLICY_VERSION_MINIMUM=3.5

    -DCMAKE_C_COMPILER="clang"
    -DCMAKE_CXX_COMPILER="clang++"
    -DCUDA_NVCC_FLAGS="-gencode;arch=compute_${CUDAARCHS},code=sm_${CUDAARCHS}"

    -DUSE_MPI=OFF
    -DUSE_MPIMT=OFF
    -DUSE_CUB=OFF
    -DUSE_DUST=OFF
    -DUSE_OPENGL=OFF
)

cmake \
    "${args[@]}" \
    -B"build" \
    "Bonsai/runtime"

make -O -C "build" bonsai2_slowdust -j"$(nproc)"
