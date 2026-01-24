#!/bin/bash

set -e

# Configure.
cmake \
    -DCMAKE_BUILD_TYPE=Release \
    -DVLLM_PYTHON_EXECUTABLE=`which python3` \
    -DCMAKE_CUDA_COMPILER="${CUDA_PATH}/bin/nvcc" \
    -DCMAKE_CUDA_ARCHITECTURES="${SCALE_FAKE_CUDA_ARCH}" \
    -DBUILD_TESTING=ON \
    -DCMAKE_CTEST_ARGUMENTS="--output-on-failure --output-junit vllm.xml" \
    -DCMAKE_INSTALL_PREFIX="install" \
    -B"build" \
    "vllm"

make -C "build" install -j"$(nproc)"
#
## Build the Python package, and install it.
#cd "${OUT_DIR}/vllm/build/vllm/python"
#python3 -m build --wheel --no-isolation
#python3 -m installer --prefix= --destdir="${OUT_DIR}/vllm/install" dist/*.whl
