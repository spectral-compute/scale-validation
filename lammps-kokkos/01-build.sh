#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh

# MPI not strictly needed here, currently single-GPU
MPI_DIR="$(realpath ../)/openmpi/install"
if [ -e "${MPI_DIR}" ] ; then
    echo "Found OpenMPI project at ${MPI_DIR}; building with MPI"
    MPI_ARGS=(-DBUILD_MPI=yes -DMPI_HOME="${MPI_DIR}")
elif command -v mpicxx > /dev/null 2>&1 ; then
    echo "No OpenMPI project at ${MPI_DIR}; using mpicxx from $(command -v mpicxx)"
    MPI_ARGS=(-DBUILD_MPI=yes)
else
    echo "No OpenMPI project or mpicxx on PATH; building serial"
    MPI_ARGS=(-DBUILD_MPI=no)
fi

# default 86, as master hardcoded; scaleenv normally sets it
CUDAARCHS="${CUDAARCHS:-86}"

# Kokkos wants a named architecture symbol rather than a compute capability number, so
# ${CUDAARCHS} can't be passed through the way the GPU package build does it
# Mapping our targets; anything unrecognised falls back to AMPERE86, which is what kokkos/01-build.sh hardcodes.
# Only matters for testing on nvidia GPUs really, we are always 86
case "${CUDAARCHS}" in
    70)  KOKKOS_ARCH=VOLTA70 ;;
    75)  KOKKOS_ARCH=TURING75 ;;
    80)  KOKKOS_ARCH=AMPERE80 ;;
    86)  KOKKOS_ARCH=AMPERE86 ;;
    89)  KOKKOS_ARCH=ADA89 ;;
    90)  KOKKOS_ARCH=HOPPER90 ;;
    100) KOKKOS_ARCH=BLACKWELL100 ;;
    120) KOKKOS_ARCH=BLACKWELL120 ;;
    *)
        KOKKOS_ARCH=AMPERE86
        echo "Unrecognised CUDAARCHS=${CUDAARCHS}; falling back to Kokkos_ARCH_${KOKKOS_ARCH}" 1>&2
    ;;
esac
echo "Building for Kokkos_ARCH_${KOKKOS_ARCH} (CUDAARCHS=${CUDAARCHS})"

args=(
    # Build the KOKKOS package against its CUDA backend, and not the GPU package
    -DPKG_KOKKOS=yes
    -DPKG_GPU=no

    -DKokkos_ENABLE_CUDA=ON
    -DKokkos_ARCH_${KOKKOS_ARCH}=ON

    # see kokkos/01-build.sh
    -DCMAKE_CXX_COMPILER=clang++
    -DCMAKE_CUDA_FLAGS="-DSCALE_WARP_SIZE=32"
    -DCMAKE_CXX_FLAGS="-DSCALE_WARP_SIZE=32"
    -DCMAKE_C_FLAGS="-DSCALE_WARP_SIZE=32"

    -DPKG_MOLECULE=yes
    -DPKG_KSPACE=yes
    -DPKG_RIGID=yes
    -DPKG_MANYBODY=yes

    # dump image/movie, for animation
    -DPKG_GRAPHICS=yes

    -DENABLE_TESTING=on

    -DCMAKE_BUILD_TYPE=Release
)

# LAMMPS's CMakeLists.txt lives in cmake/, not at the root of the clone.
cmake \
    "${args[@]}" \
    "${MPI_ARGS[@]}" \
    -B"build" \
    "lammps-kokkos/cmake"

make -O -C "build" -j"$(nproc)"
