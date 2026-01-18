#!/bin/bash

set -e
SCRIPT_DIR="$(realpath "$(dirname "$0")")"
source "${SCRIPT_DIR}"/../util/args.sh "$@"

export PATH="${CUDA_PATH}/bin:${PATH}"
export LD_LIBRARY_PATH="${CUDA_PATH}/lib"

# Configure.
cmake \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_CUDA_COMPILER="${CUDA_PATH}/bin/nvcc" \
    -DCMAKE_CUDA_ARCHITECTURES="$(echo "${GPU_ARCH}" | sed -E 's/sm_//g')" \
    -DBUILD_SHARED_LIBS=ON \
    -DBUILD_TESTING=ON \
    -DCMAKE_CTEST_ARGUMENTS="--output-on-failure --output-junit faiss.xml" \
    -DCMAKE_INSTALL_PREFIX="${OUT_DIR}/faiss/install" \
    -B"${OUT_DIR}/faiss/build" \
    "${OUT_DIR}/faiss/faiss"

make -C "${OUT_DIR}/faiss/build" install -j"$(nproc)"

# Build the Python package, and install it.
cd "${OUT_DIR}/faiss/build/faiss/python"
python3 -m build --wheel --no-isolation
python3 -m installer --prefix= --destdir="${OUT_DIR}/faiss/install" dist/*.whl
