#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh

# Upstream works around an nvcc crash by passing nvcc_wrapper's --host-only for one file whenever Kokkos
# uses CUDA, even when the compiler is clang++ (as here), which rejects it.
GRAPHICS_CMAKE=lammps-kokkos/cmake/Modules/Packages/GRAPHICS.cmake
grep -q 'COMPILE_OPTIONS "--host-only"' "${GRAPHICS_CMAKE}"
sed -i 's/COMPILE_OPTIONS "--host-only"/COMPILE_OPTIONS ""/' "${GRAPHICS_CMAKE}"

# MPI not strictly needed here, currently single-GPU
MPI_DIR="$(realpath ../)/openmpi/install"
if [ -e "${MPI_DIR}" ] ; then
    echo "Found OpenMPI project at ${MPI_DIR}; building with MPI"
    MPI_ARGS=(-DBUILD_MPI=yes -DMPI_HOME="${MPI_DIR}")
else
    echo "No OpenMPI project at ${MPI_DIR}; building serial"
    MPI_ARGS=(-DBUILD_MPI=no)
fi

# default 86, as master hardcoded; scaleenv normally sets it
CUDAARCHS="${CUDAARCHS:-86}"

# Kokkos wants a named architecture symbol rather than a compute capability number, so
# ${CUDAARCHS} can't be passed through the way the GPU package build does it
# Mapping our targets; anything unrecognised is an error rather than a silent guess.
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
        echo "Unrecognised CUDAARCHS=${CUDAARCHS}; add it to the Kokkos_ARCH mapping in $0" 1>&2
        exit 1
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

    # No CPU threading used here. On NVIDIA the libomp that SCALE's clang links isn't on the runtime path
    -DBUILD_OMP=no

    -DPKG_MOLECULE=yes
    -DPKG_KSPACE=yes
    # Upstream's recommendation for the CUDA backend. The FFT unit tests also need it: they link
    # CUDA::cudart, which only FFT_KOKKOS=CUFFT finds.
    -DFFT_KOKKOS=CUFFT
    -DPKG_RIGID=yes
    -DPKG_MANYBODY=yes

    # dump image/movie, for animation
    -DPKG_GRAPHICS=yes

    -DENABLE_TESTING=on
    # With testing on, LAMMPS links with lld when it finds it, but passes the generic `lld` (which
    # refuses to run under that name) as --ld-path whenever that's first on PATH, as SCALE's is.
    -DLAMMPS_CUSTOM_LINKER=default

    -DCMAKE_BUILD_TYPE=Release
)

# LAMMPS's CMakeLists.txt lives in cmake/, not at the root of the clone.
cmake \
    "${args[@]}" \
    "${MPI_ARGS[@]}" \
    -B"build" \
    "lammps-kokkos/cmake"

make -O -C "build" -j"$(nproc)"
