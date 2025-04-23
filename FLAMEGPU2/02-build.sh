#!/bin/bash

set -ETeuo pipefail
SCRIPT_DIR="$(realpath "$(dirname "$0")")"
source "${SCRIPT_DIR}"/../util/args.sh "$@"

rm -rf "${OUT_DIR}/FLAMEGPU2/build"

cmake \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_CUDA_COMPILER="${CUDA_PATH}/bin/nvcc" \
    -DCMAKE_CUDA_ARCHITECTURES="$(echo "${GPU_ARCH}" | sed -E 's/sm_//g')" \
    -DCMAKE_PREFIX_PATH="${CUDA_PATH}" \
    -DFLAMEGPU_BUILD_TESTS=ON \
    -B"${OUT_DIR}/FLAMEGPU2/build" \
    "${OUT_DIR}/FLAMEGPU2/FLAMEGPU2"

# Make sure we actually found CUDA.
"${SCRIPT_DIR}"/../util/check-cmake-cuda-version.sh "${OUT_DIR}/FLAMEGPU2/build"

# Build.
if [ "${VERBOSE}" == "1" ] ; then
    VERBOSE="VERBOSE=1"
else
    VERBOSE=
fi
make -C "${OUT_DIR}/FLAMEGPU2/build" -j"${BUILD_JOBS}" ${VERBOSE}
