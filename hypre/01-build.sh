#!/bin/bash

set -ETeuo pipefail
SCRIPT_DIR="$(realpath "$(dirname "$0")")"
source "${SCRIPT_DIR}"/../util/args.sh "$@"

# Clean up any previous stuff.
rm -rf "${OUT_DIR}/hypre/build"

# Copy the source tree for in-tree build because the cmake build system builds fewer tests.
cp -r "${OUT_DIR}/hypre/hypre" "${OUT_DIR}/hypre/build"

# Configure
SM="$(echo "${GPU_ARCH}" | sed -E 's/sm_//g')"

export NVCC_PREPEND_FLAGS="-ccbin ${CUDA_PATH}/bin"

cd "${OUT_DIR}/hypre/build/src"
HYPRE_CUDA_SM="${SM}" \
    ./configure --with-cuda --with-gpu-arch="${SM}" --disable-onemklsparse --disable-onemklblas --disable-onemklrand

# Build.
if [ "${VERBOSE}" == "1" ] ; then
    VERBOSE="VERBOSE=1"
else
    VERBOSE=
fi
make test -j"${BUILD_JOBS}" "${VERBOSE}"
