#!/usr/bin/env bash
# shellcheck source-path=SCRIPTDIR
. "$(dirname "$0")"/../../util/prelude.sh

# The base 02-build.sh's GPU package build, with the HIP backend instead of
# SCALE's CUDA one. Same packages and precision; no unit tests.
args=(
    -DPKG_GPU=yes
    -DGPU_API=hip
    -DGPU_ARCH="${TEST_GPU_ARCH}"
    -DGPU_PREC=mixed
    -DCMAKE_CXX_COMPILER=hipcc
    -DBUILD_MPI=no
    -DPKG_MOLECULE=yes
    -DPKG_KSPACE=yes
    -DPKG_RIGID=yes
    -DPKG_MANYBODY=yes
    -DPKG_GRAPHICS=yes
    -DPKG_ASPHERE=yes
    -DWITH_PNG=no
    -DCMAKE_BUILD_TYPE=Release
)
cmake "${args[@]}" -B"build" "lammps/cmake"
make -O -C "build" -j"$(nproc)"
