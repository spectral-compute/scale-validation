#!/bin/bash

set -ETeuo pipefail
SCRIPT_DIR="$(realpath "$(dirname "$0")")"
source "${SCRIPT_DIR}"/../util/args.sh "$@"

# Clean up any previous stuff.
rm -rf "${OUT_DIR}/cuSZ/build"

# Configure.
cmake \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_CUDA_COMPILER="${CUDA_DIR}/bin/nvcc" \
    -DCMAKE_CXX_FLAGS="-Wno-unused-result -fpermissive" \
    -DCMAKE_CUDA_FLAGS="-Wno-unused-result" \
    -DCMAKE_CUDA_ARCHITECTURES="$(echo "${GPU_ARCH}" | sed -E 's/sm_//g')" \
    -DBUILD_TESTING=On \
    -DPSZ_BUILD_EXAMPLES=On \
    -DCMAKE_INSTALL_PREFIX="${OUT_DIR}/cuSZ/install" \
    -B"${OUT_DIR}/cuSZ/build" \
    "${OUT_DIR}/cuSZ/cuSZ"

# Make sure we actually found CUDA.
"${SCRIPT_DIR}"/../util/check-cmake-cuda-version.sh "${OUT_DIR}/cuSZ/build"

# Build.
if [ "${VERBOSE}" == "1" ] ; then
    VERBOSE="VERBOSE=1"
else
    VERBOSE=
fi
make -C "${OUT_DIR}/cuSZ/build" install -j"${BUILD_JOBS}" "${VERBOSE}"
