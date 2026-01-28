#!/bin/bash

set -e

# Configure.
cmake \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX="install" \
    -DCMAKE_C_COMPILER="clang" \
    -DCMAKE_CXX_COMPILER="clang++" \
    -DCMAKE_CUDA_COMPILER="nvcc" \
    -DCMAKE_CUDA_ARCHITECTURES="${CUDAARCHS}" \
    -DUSE_CUDA=ON \
    -DKEEP_BUILD_ARTIFACTS_IN_BINARY_DIR=ON \
    -DGOOGLE_TEST=ON \
    -B"build" \
    "xgboost"

make -C "build" install -j"$(nproc)"

# Build the Python package.
cp -r "xgboost" "pybuild"

python3 -m build --wheel --no-isolation "xgboost/python-package"
python3 -m installer "xgboost/python-package/dist"/*.whl \
    --prefix= --destdir="install" --compile-bytecode=2

# For some reason, Arch and Ubuntu disagree on whether this directory gets created.

PY_VER_PATH=$(python3 --version | cut -d ' ' -f 2 | cut -d '.' -f 1-2) # Like "3.12"
if [ -e "install/lib/python${PY_VER_PATH}" ] ; then
    rm "install/lib/python${PY_VER_PATH}/site-packages/xgboost/lib/libxgboost.so"
    ln -s ../../../../libxgboost.so "install/lib/python${PY_VER_PATH}/site-packages/xgboost/lib/libxgboost.so"
fi
