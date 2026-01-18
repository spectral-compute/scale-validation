#!/bin/bash

set -ETeuo pipefail
SCRIPT_DIR="$(realpath "$(dirname "$0")")"
source "${SCRIPT_DIR}"/../util/args.sh "$@"

# Configure.
cmake \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_CXX_FLAGS="-fpermissive" \
    -DCMAKE_CUDA_ARCHITECTURES="$(echo "${GPU_ARCH}" | sed -E 's/sm_//g')" \
    -DBUILD_TESTING=On \
    -DPSZ_BUILD_EXAMPLES=On \
    -DCMAKE_INSTALL_PREFIX="${OUT_DIR}/cuSZ/install" \
    -B"${OUT_DIR}/cuSZ/build" \
    "${OUT_DIR}/cuSZ/cuSZ"

make -C "${OUT_DIR}/cuSZ/build" install -j"$(nproc)"
