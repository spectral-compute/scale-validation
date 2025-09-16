#!/bin/bash

set -ETeuo pipefail
SCRIPT_DIR="$(realpath "$(dirname "$0")")"
source "${SCRIPT_DIR}"/../util/args.sh "$@"

export SCALE_CUDA_VERSION="11.4"

# getting
#CMake Error: Error required internal CMake variable not set, cmake may not be built correctly.
#Missing variable is:
#_CMAKE_CUDA_WHOLE_FLAG
# possible workaround is -std=c++17 -stdlib=libc++ -D_ALLOW_UNSUPPORTED_LIBCPP in CUDA_FLAGS
# that gets us to   Clang device compilation for CUTLASS requires CMake 3.30 or higher.
# installed 4.1.1 under /usr/local

# trying to find nvidia::cudart with the prefix path
#    -DCMAKE_CUDA_FLAGS="-Wno-unused-result -Wno-deprecated-declarations -std=c++17 -stdlib=libc++ -D_ALLOW_UNSUPPORTED_LIBCPP" \
# /usr/local/cuda-13 has more stuff in it, e.g. cuda_runtime.h, than /usr/local/cuda
# Configure.
/usr/local/bin/cmake \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_PREFIX_PATH=/usr/lib/x86_64-linux-gnu \
    -DCUTLASS_NVCC_ARCHS="$(echo "${GPU_ARCH}" | sed -E 's/sm_//g')" \
    -DCUTLASS_TEST_UNIT_ENABLE_WARNINGS=ON \
    -DCMAKE_CUDA_ARCHITECTURES="$(echo "${GPU_ARCH}" | sed -E 's/sm_//g')" \
    -DCMAKE_CUDA_COMPILER="/usr/local/cuda-13/bin/nvcc" \
    -DCUDA_TOOLKIT_ROOT_DIR="/usr/local/cuda-13" \
    -DCUDA_CUDA_FLAGS="-Wno-unused-result -Wno-deprecated-declarations" \
    -DCMAKE_CXX_COMPILER="g++" \
    -DCMAKE_C_COMPILER="gcc" \
    -B"${OUT_DIR}/cutlass/build" \
    "${OUT_DIR}/cutlass/cutlass"

# Make sure we actually found CUDA.
"${SCRIPT_DIR}"/../util/check-cmake-cuda-version.sh "${OUT_DIR}/cutlass/build"

# Build.
cmake --build "${OUT_DIR}/cutlass/build" -j"${BUILD_JOBS}"
