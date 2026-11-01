#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh

# shellcheck source=util/env.sh
. "${SCRIPT_DIR}/util/env.sh"

cmake -S json-fortran -B json-fortran/build -DCMAKE_INSTALL_PREFIX="${DEPS}" \
    -DCMAKE_Fortran_COMPILER=gfortran -DUSE_GNU_INSTALL_CONVENTION=ON -DSKIP_DOC_GEN=ON -Wno-dev
cmake --build json-fortran/build --parallel "$(nproc)"
cmake --install json-fortran/build

# pFUnit, for neko's unit tests.
cmake -S pFUnit -B pFUnit/build -DCMAKE_INSTALL_PREFIX="${DEPS}/pfunit" \
    -DCMAKE_Fortran_COMPILER=mpif90 -DSKIP_OPENMP=YES -DSKIP_ROBUST=YES -DSKIP_ESMF=YES \
    -DENABLE_TESTS=NO -Wno-dev
cmake --build pFUnit/build --parallel "$(nproc)"
cmake --install pFUnit/build
