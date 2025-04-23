#!/bin/bash

set -ETeuo pipefail
SCRIPT_DIR="$(realpath "$(dirname "$0")")"
source "${SCRIPT_DIR}"/../util/args.sh "$@"

# Clean up any previous stuff.
rm -rf "${OUT_DIR}/timemachine/build"
mkdir "${OUT_DIR}/timemachine/build"

cd "${OUT_DIR}/timemachine/build"
python3.12 -m venv venv
source venv/bin/activate

# Configure.
ARCH_TGT=$(echo "${GPU_ARCH}" | sed -E 's/sm_//g')
cmake \
    -DCUDA_ARCH=${ARCH_TGT} \
    -DCMAKE_CUDA_ARCHITECTURES=${ARCH_TGT} \
    -DCMAKE_COMPILE_WARNING_AS_ERROR=OFF \
    -DCMAKE_INSTALL_PREFIX="${OUT_DIR}/timemachine/install" \
    -B "${OUT_DIR}/timemachine/build" \
    -S "${OUT_DIR}/timemachine/timemachine/timemachine/cpp"

make -C "${OUT_DIR}/timemachine/build" install -j"${BUILD_JOBS}" "${VERBOSE}"
