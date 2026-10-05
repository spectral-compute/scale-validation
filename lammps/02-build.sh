#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh

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

args=(
    # Build the GPU package against its CUDA artisanal hand-written CUDA in lib/gpu backend
    # PKG_GPU defaults OFF in LAMMPS's cmake; without it GPU_API/GPU_ARCH/GPU_PREC
    # are no-ops and we get "package gpu" errors at runtime
    -DPKG_GPU=yes
    -DGPU_API=cuda

    -DGPU_ARCH=sm_${CUDAARCHS}
    -DGPU_PREC=mixed

    -DCMAKE_CUDA_COMPILER="nvcc"
    -DCMAKE_CUDA_ARCHITECTURES="${CUDAARCHS}"

    # SCALE master added its own bin2c, but we still need this shim: no -fatbin
    # support yet, and that's maybe what our compiled device code actually needs bin2c-ing from
    -DBIN2C="$(realpath "$(dirname "$0")")/bin2c-shim.py"

    -DCUDA_BUILD_MULTIARCH=OFF

    # The packages holding most of the GPU package's accelerated pair and kspace styles.
    # Without them the MolPairStyle:/ManybodyPairStyle:/KSpaceStyle: tests that 03-test.sh
    # selects have nothing to test and all skip.
    -DPKG_MOLECULE=yes
    -DPKG_KSPACE=yes
    -DPKG_RIGID=yes
    -DPKG_MANYBODY=yes

    # dump image/movie, for animation
    -DPKG_GRAPHICS=yes

    # for 07-animated-scale.sh
    -DPKG_ASPHERE=yes

    # off: only the by-hand animations (06/07) need it, and it wants libpng-dev
    # set to yes (and install libpng-dev) for pretty pictures
    -DWITH_PNG=no

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
