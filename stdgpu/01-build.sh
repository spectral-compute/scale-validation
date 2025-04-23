#!/bin/bash

set -e
SCRIPT_DIR="$(realpath "$(dirname "$0")")"
source "${SCRIPT_DIR}"/../util/args.sh "$@"

#export CC="${CUDA_PATH}/bin/gcc"
#export CXX="${CUDA_PATH}/bin/g++"
#export CUDAHOSTCXX="${CUDA_PATH}/bin/g++"


# Configure.
cmake \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_CUDA_COMPILER="${CUDA_PATH}/bin/nvcc" \
    -DCMAKE_CUDA_ARCHITECTURES="$(echo "${GPU_ARCH}" | sed -E 's/sm_//g')" \
    -DCMAKE_INSTALL_PREFIX="${OUT_DIR}/stdgpu/install" \
    -B"${OUT_DIR}/stdgpu/build" \
    "${OUT_DIR}/stdgpu/stdgpu"

# Make sure we actually found CUDA.
"${SCRIPT_DIR}"/../util/check-cmake-cuda-version.sh "${OUT_DIR}/stdgpu/build"

# Build.
if [ "${VERBOSE}" == "1" ] ; then
    VERBOSE="VERBOSE=1"
else
    VERBOSE=
fi
make -C "${OUT_DIR}/stdgpu/build" install -j"${BUILD_JOBS}" ${VERBOSE}
