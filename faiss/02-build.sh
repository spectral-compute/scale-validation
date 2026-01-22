#!/bin/bash

set -e

# Configure.
OUTDIR=$(realpath .)
cmake \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_CUDA_COMPILER="${CUDA_PATH}/bin/nvcc" \
    -DCMAKE_CUDA_ARCHITECTURES="${SCALE_FAKE_CUDA_ARCH}" \
    -DBUILD_SHARED_LIBS=ON \
    -DBUILD_TESTING=ON \
    -DCMAKE_CTEST_ARGUMENTS="--output-on-failure --output-junit faiss.xml" \
    -DCMAKE_INSTALL_PREFIX="install" \
    -B"build" \
    "faiss"

make -C "build" install -j"$(nproc)"

# Build the Python package, and install it.
cd "build/faiss/python"
python3 -m build --wheel --no-isolation
python3 -m installer --prefix= --destdir="install" dist/*.whl
cd -
