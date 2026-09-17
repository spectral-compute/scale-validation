#!/usr/bin/env bash
#
# Configure and build code_saturne's native HIP backend: the baseline SCALE's
# build of the CUDA backend is compared against.
# shellcheck source-path=SCRIPTDIR
. "$(dirname "$0")"/../../util/prelude.sh
. "$(dirname "$0")"/../common.bash

mpi_dir="${PWD}/openmpi-rocm/install"
use_openmpi "${mpi_dir}"

# See 03-build.sh: picks up the test harness patch from 01-patch.sh.
(cd code_saturne && autoreconf -i)

configure_args=(
    --prefix="${CS_INSTALL}"
    --with-mpi="${mpi_dir}"
    --enable-hip
    --disable-gui
    --with-hdf5="${DEPS_INSTALL}"
    --with-med="${DEPS_INSTALL}"
    --with-cgns="${DEPS_INSTALL}"
)

rm -rf code_saturne/build
mkdir -p code_saturne/build
cd code_saturne/build

# What code_saturne 9.2's HIP build needs on top of what configure works out:
# ROCm's headers and libraries, the AMD platform define, and hip_runtime.h
# force-included into the sources hipcc compiles.
export CPPFLAGS="-I${ROCM_PATH}/include -D__HIP_PLATFORM_AMD__"
export HIPCCFLAGS="-include hip/hip_runtime.h"
export LDFLAGS="-L${ROCM_PATH}/lib -Wl,-rpath,${ROCM_PATH}/lib -Wl,-rpath,${mpi_dir}/lib -Wl,-rpath,${DEPS_INSTALL}/lib"

HIP_ARCH_NUM="${TEST_GPU_ARCH}" ../configure "${configure_args[@]}"

make -j"$(nproc)"
make install
