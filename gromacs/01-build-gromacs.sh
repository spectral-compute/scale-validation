#!/bin/bash

set -e
SCRIPT_DIR="$(realpath "$(dirname "$0")")"
source "${SCRIPT_DIR}"/../util/args.sh "$@"

mkdir -p "${OUT_DIR}/gromacs/build"
cd "${OUT_DIR}/gromacs/build"
GROMACS_VER=2025.1

# Configure.
cmake \
    -DGMX_DISABLE_CUDA_TEXTURES=ON \
    -DCMAKE_INSTALL_PREFIX="$(pwd)/../install" \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_CUDA_ARCHITECTURES=$(echo $GPU_ARCH | sed -E 's/sm_//') \
    -DGMX_CUDA_TARGET_SM=$(echo $GPU_ARCH | sed -E 's/sm_//') \
    -DGMX_CLANG_CUDA=OFF \
    -DGMX_GPU=CUDA \
    -DGMX_BUILD_OWN_FFTW=ON \
    -DGMX_PYTHON_PACKAGE=OFF \
    -DGMX_MPI=OFF \
    -DGMX_PYTHON_BINDINGS=OFF \
    -DGMX_THREAD_MPI=OFF \
    -DCMAKE_DISABLE_FIND_PACKAGE_MPI=ON \
    -DGMX_HAVE_GPU_GRAPH_SUPPORT=OFF \
    -DGMX_NNPOT=OFF  \
    -DGMX_OPENMP=OFF \
    -DREGRESSIONTEST_PATH="${OUT_DIR}/gromacs/regressiontests-${GROMACS_VER}" \
    "${OUT_DIR}/gromacs/gromacs"

# Make sure we actually found CUDA.
"${SCRIPT_DIR}"/../util/check-cmake-cuda-version.sh "${OUT_DIR}/gromacs/build"

# Build.
if [ "${VERBOSE}" == "1" ] ; then
    VERBOSE="VERBOSE=1"
else
    VERBOSE=
fi
make -j"${BUILD_JOBS}" install ${VERBOSE}``
