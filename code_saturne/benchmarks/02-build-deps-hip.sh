#!/usr/bin/env bash
#
# The mesh libraries, plus an Open MPI of the HIP build's own. The openmpi
# project's install is built against the CUDA toolkit under test (SCALE's
# libcuda), so the HIP build gets one with ROCm as its accelerator instead.
# shellcheck source-path=SCRIPTDIR
. "$(dirname "$0")"/../../util/prelude.sh

bash "${SCRIPT_DIR}/../02-build-deps.sh"

# Same release as the openmpi project: its version from versions.txt, and the
# patch level its 00-clone.sh downloads.
version="$(get_version openmpi)"
release="openmpi-${version#v}.8"

wget "https://download.open-mpi.org/release/open-mpi/${version}/${release}.tar.bz2"
tar -xf "${release}.tar.bz2"
rm -rf openmpi-rocm
mkdir -p openmpi-rocm
mv "${release}" openmpi-rocm/source

# --with-pmix/--with-prrte=internal for the same reason as the openmpi project's
# 01-configure.sh: a system PMIx would point every rank's component path away
# from this install, and the ROCm accelerator component would never load.
configure_args=(
    --prefix="${PWD}/openmpi-rocm/install"
    --with-pmix=internal
    --with-prrte=internal
    --with-rocm="${ROCM_PATH}"
)

mkdir -p openmpi-rocm/build
(cd openmpi-rocm/build && ../source/configure "${configure_args[@]}")
make -C openmpi-rocm/build -sk -j"$(nproc)" install
