#!/bin/bash

set -e
SCRIPT_DIR="$(realpath "$(dirname "$0")")"
source "${SCRIPT_DIR}"/../util/args.sh "$@"

# Configure.
cmake \
    -DCMAKE_BUILD_TYPE=Release \
    -DCUDA_TOOLKIT_ROOT_DIR=${CUDA_PATH} \
    -DCMAKE_CUDA_COMPILER="${CUDA_PATH}/bin/nvcc" \
    -DCMAKE_C_COMPILER="${CUDA_PATH}/bin/clang" \
    -DCMAKE_CXX_COMPILER="${CUDA_PATH}/bin/clang++" \
    -DCMAKE_CUDA_HOST_COMPILER="${CUDA_PATH}/bin/clang++" \
    -DOPENMP_RUNTIME=COMP \
    -DWITH_MKL=OFF \
    -DCUDA_NVCC_FLAGS="-Wno-pass-failed -Wno-deprecated-builtins -Wno-unused-result -Wno-missing-braces -Wno-unused-parameter -Wno-sign-compare -Wno-unused-local-typedef" \
    -DCMAKE_CUDA_ARCHITECTURES="$GPU_ARCH_NUM" \
    -DCUDA_ARCH_LIST="$GPU_ARCH_DEC" \
    -DWITH_CUDA=ON \
    -DBUILD_TESTS=ON \
    -B"${OUT_DIR}/ctranslate2/ctranslate2/build" \
    "${OUT_DIR}/ctranslate2/ctranslate2"

# Build.
if [ "${VERBOSE}" == "1" ] ; then
    VERBOSE="VERBOSE=1"
else
    VERBOSE=
fi

make -C "${OUT_DIR}/ctranslate2/ctranslate2/build" -j"${BUILD_JOBS}" ${VERBOSE}
