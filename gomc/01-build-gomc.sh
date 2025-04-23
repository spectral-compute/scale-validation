#!/bin/bash

set -e
SCRIPT_DIR="$(realpath "$(dirname "$0")")"
source "${SCRIPT_DIR}"/../util/args.sh "$@"

# Compile for the architectures we want.
GPU_ARCH="$(echo "${GPU_ARCH}" | sed -E 's/^sm_//')"
for F in CMake/GOMCCUDASetup.cmake test/BuildGPUTests.cmake ; do
    sed -E "s/(\s+CUDA_ARCHITECTURES ).*/\1${GPU_ARCH}/" -i "${OUT_DIR}/gomc/GOMC/${F}"
done

# CMake detects that we're Clang, and GOMC enables libc++ for that in a way that seems to be broken.
for F in CMakeLists.txt lib/cereal-1.3.0/CMakeLists.txt ; do
    sed -E 's/-stdlib=libc[+][+]//' -i "${OUT_DIR}/gomc/GOMC/${F}"
done

# GOMC's OpenMP support tests __GNUC__'s value. Even if I set this to a larger value that causes use of the newer OpenMP
# syntax Clang expects (by default, at least), it still results in error messages.
sed -E 's/find_package\(OpenMP\)//' -i "${OUT_DIR}/gomc/GOMC/CMakeLists.txt"

# Fix the call to Difference to be non-ambiguous (needed on Nvidia too).
sed -E 's/ Difference/ ::Difference/g' -i "${OUT_DIR}/gomc/GOMC/src/GPU/CalculateForceCUDAKernel.cu"

# Configure.
cmake \
    -DCMAKE_BUILD_TYPE=RelWithDebInfo \
    -DCMAKE_CUDA_COMPILER="${CUDA_PATH}/bin/nvcc" \
    -DCMAKE_CXX_FLAGS="-fPIC" \
    -DCMAKE_CUDA_FLAGS="-fPIC" \
    -DCMAKE_CUDA_ARCHITECTURES="${GPU_ARCH}" \
    -DGOMC_GTEST=On \
    -DCMAKE_INSTALL_PREFIX="${OUT_DIR}/gomc/install" \
    -B"${OUT_DIR}/gomc/build" \
    "${OUT_DIR}/gomc/GOMC"

# Build.
if [ "${VERBOSE}" == "1" ] ; then
    VERBOSE="VERBOSE=1"
else
    VERBOSE=
fi
make -C "${OUT_DIR}/gomc/build" -j"${BUILD_JOBS}" ${VERBOSE}
