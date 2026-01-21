#!/bin/bash

set -ETeuo pipefail

# Configure.
cmake \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_CXX_FLAGS="-fpermissive" \
    -DCMAKE_CUDA_ARCHITECTURES="$(echo "${GPU_ARCH}" | sed -E 's/sm_//g')" \
    -DBUILD_TESTING=On \
    -DPSZ_BUILD_EXAMPLES=On \
    -DCMAKE_INSTALL_PREFIX="${OUT_DIR}/cuSZ/install" \
    -B"build" \
    "cuSZ"

make -C "build" install -j"$(nproc)"
