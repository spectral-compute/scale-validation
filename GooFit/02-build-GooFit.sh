#!/bin/bash

set -e

ARCHs="${SCALE_FAKE_CUDA_ARCH}}"

# TODO:
# -DGOOFIT_ARCH="${major}.${minor}" \
# (otherwise it builds for All/Common)

# Configure.
cmake \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_CUDA_COMPILER="${CUDA_PATH}/bin/nvcc" \
    -DCMAKE_CUDA_ARCHITECTURES="${ARCHs}" \
    -DGOOFIT_SUBMODULE=OFF \
    -DCUDA_TOOLKIT_ROOT_DIR="${CUDA_PATH}" \
    -DCMAKE_INSTALL_PREFIX="install" \
    -B"build" \
    "GooFit"

make -C "build" -j"$(nproc)"
