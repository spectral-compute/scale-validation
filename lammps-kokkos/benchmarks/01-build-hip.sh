#!/usr/bin/env bash
# shellcheck source-path=SCRIPTDIR
. "$(dirname "$0")"/../../util/prelude.sh

# The base 01-build.sh's KOKKOS build, on Kokkos's native HIP backend instead
# of SCALE's CUDA. Same packages; no unit tests, MPI or OpenMP.
args=(
    -DPKG_KOKKOS=yes
    -DPKG_GPU=no
    -DKokkos_ENABLE_HIP=ON
    "-DKokkos_ARCH_AMD_${TEST_GPU_ARCH^^}=ON"
    -DCMAKE_CXX_COMPILER=hipcc
    -DBUILD_OMP=no
    -DBUILD_MPI=no
    -DPKG_MOLECULE=yes
    -DPKG_KSPACE=yes
    -DFFT_KOKKOS=HIPFFT
    -DPKG_RIGID=yes
    -DPKG_MANYBODY=yes
    -DPKG_GRAPHICS=yes
    -DCMAKE_BUILD_TYPE=Release
)
cmake "${args[@]}" -B"build" "lammps-kokkos/cmake"
make -O -C "build" -j"$(nproc)"
