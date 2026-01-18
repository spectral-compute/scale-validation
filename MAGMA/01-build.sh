#!/bin/bash

set -e
SCRIPT_DIR="$(realpath "$(dirname "$0")")"
source "${SCRIPT_DIR}"/../util/args.sh "$@"

# This is incredibly cursed, but it's the official instructions!
# This generates part of the cmake build system using make.
cd "${OUT_DIR}/MAGMA/MAGMA"
echo -e "BACKEND = cuda\nFORT = true\nGPU_TARGET=sm_${GPU_ARCH}" > make.inc
make -j"$(nproc)" generate

sed -i"" -Ee 's|find_package\( *OpenMP *\)||g' "${OUT_DIR}/MAGMA/MAGMA/CMakeLists.txt"

# Configure.
cmake \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX="${OUT_DIR}/MAGMA/MAGMA/inst" \
    -DCMAKE_CUDA_COMPILER="${CUDA_PATH}/bin/nvcc" \
    -DCMAKE_C_COMPILER="${CUDA_PATH}/bin/clang" \
    -DCMAKE_CXX_COMPILER="${CUDA_PATH}/bin/clang++" \
    -DCMAKE_CUDA_ARCHITECTURES="$(echo "${GPU_ARCH}" | sed -E 's/sm_//g')" \
    -DMAGMA_ENABLE_CUDA=ON \
    -B"${OUT_DIR}/MAGMA/MAGMA/build" \
    "${OUT_DIR}/MAGMA/MAGMA"

make -C "${OUT_DIR}/MAGMA/MAGMA/build" -j"$(nproc)"
