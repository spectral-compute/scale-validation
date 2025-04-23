#!/bin/bash

set -e
SCRIPT_DIR="$(realpath "$(dirname "$0")")"
source "${SCRIPT_DIR}"/../util/args.sh "$@"

if [ ! -e "${OUT_DIR}/openmpi/install" ] ; then
    echo "Please build the OpenMPI third party project first. Use the same working directory." 1>&2
    exit 1
fi

export PATH="${CUDA_PATH}/bin:${PATH}"

# The tests require an in-tree build.
echo "Note: This script does an in-tree build, because that's required by AMGX's tests."

# Configure.
if [ -z "$(which scalediag)" ] || scalediag full-driver p2p ; then
    CMAKE_NO_MPI=Off
else
    CMAKE_NO_MPI=On
fi

cmake \
    -DCMAKE_BUILD_TYPE=RelWithDebInfo \
    -DCMAKE_CUDA_COMPILER="${CUDA_PATH}/bin/nvcc" \
    -DCMAKE_CUDA_ARCHITECTURES="$(echo "${GPU_ARCH}" | sed -E 's/sm_//g')" \
    -DCUDA_ARCH="$(echo "${GPU_ARCH}" | sed -E 's/sm_//g')" \
    -DCMAKE_NO_MPI=${CMAKE_NO_MPI} \
    -B"${OUT_DIR}/AMGX/AMGX/build" \
    "${OUT_DIR}/AMGX/AMGX"

# Build.
if [ "${VERBOSE}" == "1" ] ; then
    VERBOSE="VERBOSE=1"
else
    VERBOSE=
fi

make -C "${OUT_DIR}/AMGX/AMGX/build" -j"${BUILD_JOBS}" ${VERBOSE}
