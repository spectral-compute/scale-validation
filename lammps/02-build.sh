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

# needed for dump image for scale animation
# LAMMPS's own cmake only turns PNG support on if libpng's dev headers are already there when it configures
# but our Docker image ships the runtime lib but not the headers.
ensure_libpng() {
    [ -f /usr/include/png.h ] && return 0
    echo "libpng dev headers not found; installing..."
    [ "$(id -u)" = "0" ] || { echo "not root and libpng-dev is missing -- can't apt-get install" >&2; return 1; }
    command -v apt-get > /dev/null 2>&1 || { echo "no apt-get available to install libpng-dev" >&2; return 1; }
    apt-get update -qq && apt-get install -y --no-install-recommends libpng-dev
}
ensure_libpng

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

    # needed for dump image for scale animation
    -DWITH_PNG=yes

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
