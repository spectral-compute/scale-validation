#!/bin/bash

set -e
SCRIPT_DIR="$(realpath "$(dirname "$0")")"
source "${SCRIPT_DIR}"/../util/args.sh "$@"

# Configure.
cmake \
    -DCMAKE_BUILD_TYPE=RelWithDebInfo \
    -DVLLM_PYTHON_EXECUTABLE=`which python3` \
    -DCMAKE_CUDA_COMPILER="${CUDA_PATH}/bin/nvcc" \
    -DCMAKE_CUDA_ARCHITECTURES="$(echo "${GPU_ARCH}" | sed -E 's/sm_//g')" \
    -DBUILD_TESTING=ON \
    -DCMAKE_CTEST_ARGUMENTS="--output-on-failure --output-junit vllm.xml" \
    -DCMAKE_INSTALL_PREFIX="${OUT_DIR}/vllm/install" \
    -B"${OUT_DIR}/vllm/build" \
    "${OUT_DIR}/vllm/vllm"

# Build.
if [ "${VERBOSE}" == "1" ] ; then
    VERBOSE="VERBOSE=1"
else
    VERBOSE=
fi

make -C "${OUT_DIR}/vllm/build" install -j"${BUILD_JOBS}" ${VERBOSE}
#
## Build the Python package, and install it.
#cd "${OUT_DIR}/vllm/build/vllm/python"
#python3 -m build --wheel --no-isolation
#python3 -m installer --prefix= --destdir="${OUT_DIR}/vllm/install" dist/*.whl
