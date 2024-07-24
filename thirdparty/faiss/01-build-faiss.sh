#!/bin/bash

set -e
SCRIPT_DIR="$(realpath "$(dirname "$0")")"
source "${SCRIPT_DIR}"/../util/args.sh "$@"

export PATH="${CUDA_DIR}/bin:${PATH}"

# Configure.
cmake \
    -DCMAKE_BUILD_TYPE=RelWithDebInfo \
    -DCMAKE_CUDA_COMPILER="${CUDA_DIR}/bin/nvcc" \
    -DCMAKE_CXX_FLAGS="-Wno-unused-result" \
    -DCMAKE_CUDA_FLAGS="-Wno-unused-result" \
    -DCMAKE_CUDA_ARCHITECTURES="$(echo "${GPU_ARCH}" | sed -E 's/sm_//g')" \
    -DBUILD_TESTING=ON \
    -DCMAKE_CTEST_ARGUMENTS="--output-on-failure --output-junit faiss.xml" \
    -DCMAKE_INSTALL_PREFIX="${OUT_DIR}/faiss/install" \
    -B"${OUT_DIR}/faiss/build" \
    "${OUT_DIR}/faiss/faiss"

# Build.
if [ "${VERBOSE}" == "1" ] ; then
    VERBOSE="VERBOSE=1"
else
    VERBOSE=
fi

make -C "${OUT_DIR}/faiss/build" install -j"${BUILD_JOBS}" ${VERBOSE}

# Build the Python package, and install it.
cd "${OUT_DIR}/faiss/build/faiss/python"
python3 -m build --wheel --no-isolation
python3 -m installer --prefix= --destdir="${OUT_DIR}/faiss/install" dist/*.whl
