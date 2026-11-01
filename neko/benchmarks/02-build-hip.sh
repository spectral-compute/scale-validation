#!/usr/bin/env bash
# shellcheck source-path=SCRIPTDIR
. "$(dirname "$0")"/../../util/prelude.sh
# shellcheck source=../util/env.sh
. "${SCRIPT_DIR}/../util/env.sh"

# Neko's native HIP backend, for comparison.
cd neko
./regen.sh
args=(
    FC=mpif90
    CC=mpicc
    FCFLAGS="-O3"
    HIPCC="${ROCM_PATH}/bin/hipcc"
    HIP_HIPCC_FLAGS="-O3 -fPIE --offload-arch=${TEST_GPU_ARCH}"
    --with-hip="${ROCM_PATH}"
    --prefix="$(realpath ..)/install"
)
./configure "${args[@]}"
make -j"$(nproc)"
make install
