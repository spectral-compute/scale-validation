#!/bin/bash

set -euo pipefail

# native PKG_GPU path fails due to missing -fatbin in SCALE nvcc

# cmake \
#   -S "lammps/cmake" \
#   -B "build" \
#   -D CMAKE_BUILD_TYPE=Release \
#   -D BUILD_MPI=off \
#   -D PKG_GPU=on \
#   -D GPU_API=cuda \
#   -D CUDA_BUILD_MULTIARCH=off \ # nvcc: error: unsupported CUDA gpu architecture: all
#   -D GPU_ARCH="sm_${CUDAARCHS}" \
#   -D CMAKE_CUDA_ARCHITECTURES="${CUDAARCHS}"

# soooooo trying to build with PKG_KOKKOS=on + Kokkos_ENABLE_CUDA instead:
# (which seems to work)

# this is cursed, but unfortunately what KOKKOS requires? :p
KOKKOS_ARCH="NATIVE"
case "${CUDAARCHS:-}" in
  70) KOKKOS_ARCH="VOLTA70" ;;
  72) KOKKOS_ARCH="VOLTA72" ;;
  75) KOKKOS_ARCH="TURING75" ;;
  80) KOKKOS_ARCH="AMPERE80" ;;
  86) KOKKOS_ARCH="AMPERE86" ;;
  87) KOKKOS_ARCH="AMPERE87" ;;
  89) KOKKOS_ARCH="ADA89" ;;
  90) KOKKOS_ARCH="HOPPER90" ;;
  120) KOKKOS_ARCH="BLACKWELL120" ;;
esac

cmake \
  -S "lammps/cmake" \
  -B "build" \
  -D CMAKE_BUILD_TYPE=Release \
  -D CMAKE_CXX_STANDARD=17 \
  -D BUILD_MPI=off \
  -D BUILD_OMP=off \
  -D PKG_KOKKOS=on \
  -D Kokkos_ENABLE_SERIAL=on \
  -D Kokkos_ENABLE_CUDA=on \
  -D Kokkos_ARCH_${KOKKOS_ARCH}=on \
  -D CMAKE_CXX_COMPILER="$(realpath "lammps/lib/kokkos/bin/nvcc_wrapper")"

cmake --build "build" -j"$(nproc)"
