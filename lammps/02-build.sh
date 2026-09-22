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

args=(
    # Build the GPU package against its CUDA artisanal hand-written CUDA in lib/gpu backend
    -DGPU_API=cuda

    -DGPU_ARCH=sm_${CUDAARCHS}
    -DGPU_PREC=mixed

    -DCMAKE_CUDA_COMPILER="nvcc"
    -DCMAKE_CUDA_ARCHITECTURES="${CUDAARCHS}"

    # SCALE 1.7.3 doesn't ship a bin2c anywhere, unlike NVIDIA, but lammps wants it
    # Patch shim script reimplements bin2c's byte-to-C-array output
    -DBIN2C="$(realpath "$(dirname "$0")")/bin2c-shim.py"

    -DCUDA_BUILD_MULTIARCH=OFF

    # The packages holding most of the GPU package's accelerated pair and kspace styles.
    # Without them the MolPairStyle:/ManybodyPairStyle:/KSpaceStyle: tests that 03-test.sh
    # selects have nothing to test and all skip.
    -DPKG_MOLECULE=yes
    -DPKG_KSPACE=yes
    -DPKG_RIGID=yes
    -DPKG_MANYBODY=yes

    # and the upstream GoogleTest unit test suite that 03-test.sh runs
    -DENABLE_TESTING=on

    -DCMAKE_BUILD_TYPE=Release
)

# LAMMPS's CMakeLists.txt lives in cmake/, not at the root of the clone.
cmake \
    "${args[@]}" \
    "${MPI_ARGS[@]}" \
    -B"build" \
    "lammps/cmake"

make -O -C "build" -j"$(nproc)"
