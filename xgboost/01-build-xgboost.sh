#!/bin/bash

set -e
SCRIPT_DIR="$(realpath "$(dirname "$0")")"
source "${SCRIPT_DIR}"/../util/args.sh "$@"

# Configure.
cmake \
    -DCMAKE_BUILD_TYPE=RelWithDebInfo \
    -DCMAKE_INSTALL_PREFIX="${OUT_DIR}/xgboost/install" \
    -DCMAKE_C_COMPILER="${CUDA_PATH}/bin/clang" \
    -DCMAKE_CXX_COMPILER="${CUDA_PATH}/bin/clang++" \
    -DCMAKE_CUDA_COMPILER="${CUDA_PATH}/bin/nvcc" \
    -DCMAKE_CUDA_ARCHITECTURES="$(echo "${GPU_ARCH}" | sed -E 's/sm_//g')" \
    -DUSE_CUDA=ON \
    -DKEEP_BUILD_ARTIFACTS_IN_BINARY_DIR=ON \
    -DGOOGLE_TEST=ON \
    -B"${OUT_DIR}/xgboost/build" \
    "${OUT_DIR}/xgboost/xgboost"

# Build.
if [ "${VERBOSE}" == "1" ] ; then
    VERBOSE="VERBOSE=1"
else
    VERBOSE=
fi

rm -rf "${OUT_DIR}/xgboost/install"
make -C "${OUT_DIR}/xgboost/build" install -j"${BUILD_JOBS}" ${VERBOSE}

# Build the Python package.
rm -rf "${OUT_DIR}/xgboost/pybuild"
cp -r "${OUT_DIR}/xgboost/xgboost" "${OUT_DIR}/xgboost/pybuild"

python3 -m build --wheel --no-isolation "${OUT_DIR}/xgboost/xgboost/python-package"
python3 -m installer "${OUT_DIR}/xgboost/xgboost/python-package/dist"/*.whl \
    --prefix= --destdir="${OUT_DIR}/xgboost/install" --compile-bytecode=2

# For some reason, Arch and Ubuntu disagree on whether this directory gets created.
if [ -e "${OUT_DIR}/xgboost/install/lib/python${PY_VER_PATH}" ] ; then
    rm "${OUT_DIR}/xgboost/install/lib/python${PY_VER_PATH}/site-packages/xgboost/lib/libxgboost.so"
    ln -s ../../../../libxgboost.so "${OUT_DIR}/xgboost/install/lib/python${PY_VER_PATH}/site-packages/xgboost/lib/libxgboost.so"
fi
