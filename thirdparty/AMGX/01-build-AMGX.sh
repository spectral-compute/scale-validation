#!/bin/bash

set -e
SCRIPT_DIR="$(realpath "$(dirname "$0")")"
source "${SCRIPT_DIR}"/../util/args.sh "$@"

export PATH="${CUDA_DIR}/bin:${PATH}"

# The tests require an in-tree build.
echo "Note: This script does an in-tree build, because that's required by AMGX's tests."

# We need the patched version for now.
cp "${CUDA_DIR}/include/cub/util_device.cuh" "${OUT_DIR}/AMGX/AMGX/thrust/dependencies/cub/cub"
cp "${CUDA_DIR}/include/thrust/system/cuda/detail/parallel_for.h" "${OUT_DIR}/AMGX/AMGX/thrust/thrust/system/cuda/detail/parallel_for.h"

# Patch a legitimate bug in AMGX that we warn about.
sed -E \
  's/description\(p.description\), default_value\(default_value\)/description(p.description), default_value(p.default_value)/' \
  -i "${OUT_DIR}/AMGX/AMGX/include/amg_config.h"

# Configure.
cmake \
    -DCMAKE_BUILD_TYPE=RelWithDebInfo \
    -DCMAKE_CUDA_COMPILER="${CUDA_DIR}/bin/nvcc" \
    -DCMAKE_CXX_FLAGS="-Wno-unused-result -Wno-unused-command-line-argument" \
    -DCMAKE_CUDA_FLAGS="-Wno-unused-result -Wno-unused-command-line-argument" \
    -DCMAKE_CUDA_ARCHITECTURES="$(echo "${GPU_ARCH}" | sed -E 's/sm_//g')" \
    -DCMAKE_NO_MPI=1 \
    -B"${OUT_DIR}/AMGX/AMGX/build" \
    "${OUT_DIR}/AMGX/AMGX"

# Build.
if [ "${VERBOSE}" == "1" ] ; then
    VERBOSE="VERBOSE=1"
else
    VERBOSE=
fi

make -C "${OUT_DIR}/AMGX/AMGX/build" -j"${BUILD_JOBS}" ${VERBOSE}
