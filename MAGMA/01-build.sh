#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh

# This is incredibly cursed, but it's the official instructions!
# This generates part of the cmake build system using make.
echo -e "BACKEND = cuda\nFORT = true\nGPU_TARGET=sm_${CUDAARCHS}" >MAGMA/make.inc
make -O -C MAGMA -j"$(nproc)" generate

sed -i"" -Ee 's|find_package\( *OpenMP *\)||g' "MAGMA/CMakeLists.txt"

args=(
    -DCMAKE_BUILD_TYPE=Release
    -DCMAKE_CUDA_COMPILER="nvcc"
    -DCMAKE_C_COMPILER="clang"
    -DCMAKE_CXX_COMPILER="clang++"
    -DCMAKE_CUDA_ARCHITECTURES="${CUDAARCHS}"
    -DCMAKE_INSTALL_PREFIX="${OUT_DIR}/MAGMA/MAGMA/inst"

    -DMAGMA_ENABLE_CUDA=ON
)

cmake \
    "${args[@]}" \
    -B"build" \
    "MAGMA"

make -O -C "build" -j"$(nproc)"
