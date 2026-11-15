#!/usr/bin/env bash
# shellcheck source-path=SCRIPTDIR
. "$(dirname "$0")"/../../util/prelude.sh

# The base 02-build.sh's configuration, with GROMACS's HIP backend instead of
# CUDA. Same thread-MPI, no-OpenMP, build-own-FFTW setup.
GMX_SIMD=Auto
if [ "${NO_TUNE_NATIVE:-0}" == "1" ]; then
    GMX_SIMD=AVX2_256
fi
args=(
    -DGMX_GPU=HIP
    -DGMX_HIP_TARGET_ARCH="${TEST_GPU_ARCH}"
    -DGMX_TEST_TIMEOUT_FACTOR=4
    -DCMAKE_INSTALL_PREFIX="install"
    -DCMAKE_BUILD_TYPE=RelWithDebInfo
    -DGMX_SIMD="$GMX_SIMD"
    -DGMX_BUILD_OWN_FFTW=ON
    -DCMAKE_DISABLE_FIND_PACKAGE_MPI=ON
    -DGMX_THREAD_MPI=ON
    -DGMX_OPENMP=OFF
    -DGMX_MPI=OFF
    -DGMX_PYTHON_PACKAGE=OFF
    -DGMX_PYTHON_BINDINGS=OFF
    -DGMX_NNPOT=OFF
)
cmake "${args[@]}" -B"build" "gromacs"
make -O -C build -j"$(nproc)" install
