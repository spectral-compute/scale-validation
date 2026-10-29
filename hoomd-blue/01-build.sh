#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh

python3 -m venv venv
venv/bin/pip install numpy pybind11 gsd pytest rowan

MPI_DIR="$(realpath ../)/openmpi/install"
if [ -e "${MPI_DIR}" ]; then
    echo "Found OpenMPI project at ${MPI_DIR}; building with MPI"
    MPICC="${MPI_DIR}/bin/mpicc" venv/bin/pip install --no-binary mpi4py mpi4py

    # Header-only, but HOOMD wants its CMake package.
    do_clone cereal https://github.com/USCiLab/cereal.git "$(get_version cereal)"
    cmake -B cereal-build -S cereal -DJUST_INSTALL_CEREAL=ON -DCMAKE_INSTALL_PREFIX="$(realpath .)/cereal-install"
    cmake --install cereal-build

    MPI_ARGS=(-DENABLE_MPI=on -DMPI_HOME="${MPI_DIR}" -Dcereal_ROOT="$(realpath cereal-install)")
else
    echo "No OpenMPI project at ${MPI_DIR}; building without MPI"
    MPI_ARGS=(-DENABLE_MPI=off)
fi

args=(
    -DENABLE_GPU=on
    -DCMAKE_CUDA_COMPILER=nvcc
    -DCMAKE_CUDA_ARCHITECTURES="${CUDAARCHS}"

    -DBUILD_MD=on
    -DBUILD_MPCD=on
    -DBUILD_HPMC=on
    -DBUILD_TESTING=on

    -DPython_EXECUTABLE="$(realpath venv/bin/python)"
    -Dpybind11_ROOT="$(venv/bin/python -m pybind11 --cmakedir)"
    -DCMAKE_INSTALL_PREFIX="$(realpath .)/install"
    -DCMAKE_BUILD_TYPE=Release
    -GNinja
)

cmake "${args[@]}" "${MPI_ARGS[@]}" -B build -S hoomd-blue

# -k 0: build as much as possible, for more signal on what's unsupported.
ninja -C build -k 0 install
