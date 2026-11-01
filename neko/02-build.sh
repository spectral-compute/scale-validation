#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh
# shellcheck source=util/env.sh
. "${SCRIPT_DIR}/util/env.sh"

PFUNIT_DIR="$(find "${DEPS}/pfunit" -maxdepth 2 -name 'PFUNIT-*' -type d | head -1)"

cd neko
./regen.sh
args=(
    FC=mpif90
    CC=mpicc
    FCFLAGS="-O3"
    CUDA_ARCH="-arch=sm_${CUDAARCHS}"
    --with-cuda="${CUDA_PATH}"
    --with-pfunit="${PFUNIT_DIR}"
    --prefix="$(realpath ..)/install"
)
./configure "${args[@]}"
make -j"$(nproc)"
make install
