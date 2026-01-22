#!/bin/bash

set -ETeuo pipefail

# Configure.
cmake \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_CXX_FLAGS="-fpermissive" \
    -DCMAKE_CUDA_ARCHITECTURES="${SCALE_FAKE_CUDA_ARCH}" \
    -DBUILD_TESTING=On \
    -DPSZ_BUILD_EXAMPLES=On \
    -DCMAKE_INSTALL_PREFIX="install" \
    -B"build" \
    "cuSZ"

make -C "build" install -j"$(nproc)"
