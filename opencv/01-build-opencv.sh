#!/bin/bash

set -e
SCRIPT_DIR="$(realpath "$(dirname "$0")")"
source "${SCRIPT_DIR}"/../util/args.sh "$@"

# Configure.
cmake \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_C_COMPILER="${CUDA_PATH}/bin/gcc" \
    -DCMAKE_CXX_COMPILER="${CUDA_PATH}/bin/g++" \
    -DCUDA_ARCH_BIN="${GPU_ARCH}" \
    -DCUDA_ARCH_PTX="" \
    -DBUILD_EXAMPLES=On \
    -DBUILD_TESTS=On \
    -DBUILD_PERF_TESTS=On \
    -DINSTALL_BIN_EXAMPLES=On \
    -DINSTALL_C_EXAMPLES=On \
    -DINSTALL_TESTS=On \
    -DWITH_CUDA=On \
    -DWITH_CUFFT=Off \
    -DWITH_CUBLAS=Off \
    -DWITH_CUDNN=Off \
    -DBUILD_opencv_cudalegacy=Off \
    -DWITH_NVCUVID=Off \
    -DWITH_NVCUVENC=Off \
    -DCUDA_TOOLKIT_ROOT_DIR="${CUDA_PATH}" \
    -DOPENCV_EXTRA_MODULES_PATH="${OUT_DIR}/opencv/opencv_contrib/modules" \
    -DCMAKE_INSTALL_PREFIX="${OUT_DIR}/opencv/install" \
    -B"${OUT_DIR}/opencv/build" \
    "${OUT_DIR}/opencv/opencv"

# Make sure we actually found CUDA.
"${SCRIPT_DIR}"/../util/check-cmake-cuda-version.sh "${OUT_DIR}/opencv/build"

# Build.
if [ "${VERBOSE}" == "1" ] ; then
    VERBOSE="VERBOSE=1"
else
    VERBOSE=
fi
make -C "${OUT_DIR}/opencv/build" install -j"${BUILD_JOBS}" ${VERBOSE}
