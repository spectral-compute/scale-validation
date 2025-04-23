#!/bin/bash

set -e
SCRIPT_DIR="$(realpath "$(dirname "$0")")"
source "${SCRIPT_DIR}"/../util/args.sh "$@"

mkdir -p "${OUT_DIR}/gromacs/build"
cd "${OUT_DIR}/gromacs/build"

# Patch GROMACS to use textures even for Clang.
# sed -i '1s/^/#define GMX_DISABLE_CUDA_TEXTURES\n/' "${OUT_DIR}/gromacs/gromacs-2020.2/src/gromacs/gpu_utils/cuda_arch_utils.cuh"
#sed -E 's/define DISABLE_CUDA_TEXTURES 1/define DISABLE_CUDA_TEXTURES 0/' -i \
#    "${OUT_DIR}/gromacs/gromacs-2020.2/src/gromacs/gpu_utils/cuda_arch_utils.cuh"

# Patch GROMACS for retroactive C++ defect report: http://www.open-std.org/jtc1/sc22/wg21/docs/papers/2019/p1766r1.html
# (applied to all previous versions of C++).
#patch -p0 -d "${OUT_DIR}/gromacs/gromacs-2024.4" < "${SCRIPT_DIR}/P1766R1.patch"

# Configure.
cmake \
    -DGMX_DISABLE_CUDA_TEXTURES=ON \
    -DGMX_OPENMP=OFF \
    -DCMAKE_INSTALL_PREFIX="$(pwd)/../install" \
    -DCMAKE_BUILD_TYPE=Release \
    -DCUDA_TOOLKIT_ROOT_DIR="${CUDA_DIR}" \
    -DCMAKE_CUDA_ARCHITECTURES=$(echo $GPU_ARCH | sed -E 's/sm_//') \
    -DGMX_CUDA_TARGET_SM=$(echo $GPU_ARCH | sed -E 's/sm_//') \
    -DCMAKE_C_COMPILER="${CUDA_DIR}/bin/gcc" \
    -DCMAKE_CXX_COMPILER="${CUDA_DIR}/bin/g++" \
    -DGMX_CLANG_CUDA=OFF \
    -DGMX_GPU=CUDA \
    -DGMX_BUILD_OWN_FFTW=ON \
    -DGMX_PYTHON_PACKAGE=OFF \
    -DGMX_MPI=OFF \
    -DGMX_PYTHON_BINDINGS=OFF \
    -DGMX_THREAD_MPI=OFF \
    -DCMAKE_DISABLE_FIND_PACKAGE_MPI=ON \
    -DGMX_HAVE_GPU_GRAPH_SUPPORT=OFF \
    -DREGRESSIONTEST_PATH="${OUT_DIR}/gromacs/regressiontests-2024.4" \
    "${OUT_DIR}/gromacs/gromacs-2024.4"

# Make sure we actually found CUDA.
"${SCRIPT_DIR}"/../util/check-cmake-cuda-version.sh "${OUT_DIR}/gromacs/build"

# Build.
if [ "${VERBOSE}" == "1" ] ; then
    VERBOSE="VERBOSE=1"
else
    VERBOSE=
fi
make -j"${BUILD_JOBS}" install ${VERBOSE}``
