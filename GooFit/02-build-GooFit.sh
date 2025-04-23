#!/bin/bash

set -e
SCRIPT_DIR="$(realpath "$(dirname "$0")")"
source "${SCRIPT_DIR}"/../util/args.sh "$@"

ARCHs="$(echo "${GPU_ARCH}" | sed -E 's/sm_//g')"

# TODO:
# -DGOOFIT_ARCH="${major}.${minor}" \
# (otherwise it builds for All/Common)

# Configure.
cmake \
    -DCMAKE_BUILD_TYPE=RelWithDebInfo \
    -DCMAKE_CUDA_COMPILER="${CUDA_PATH}/bin/nvcc" \
    -DCMAKE_CUDA_ARCHITECTURES="${ARCHs}" \
    -DGOOFIT_SUBMODULE=OFF \
    -DCUDA_TOOLKIT_ROOT_DIR="${CUDA_PATH}" \
    -DCMAKE_INSTALL_PREFIX="${OUT_DIR}/GooFit/install" \
    -B"${OUT_DIR}/GooFit/build" \
    "${OUT_DIR}/GooFit/GooFit"

# Build.
if [ "${VERBOSE}" == "1" ] ; then
    VERBOSE="VERBOSE=1"
else
    VERBOSE=
fi

make -C "${OUT_DIR}/GooFit/build" -j"${BUILD_JOBS}" ${VERBOSE}
