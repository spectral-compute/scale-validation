#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh

# Some tests generate their initial conditions with Python scripts that need h5py.
python3 -m venv venv
venv/bin/pip install numpy h5py

# Quokka forces AMReX_MPI on. Prefer the OpenMPI project (built against the toolkit, so GPU-aware)
# when it has been built in the same working directory; otherwise fall back to the system MPI.
MPI_ARGS=()
MPI_DIR="$(realpath ../)/openmpi/install"
if [ -e "${MPI_DIR}" ]; then
    echo "Found OpenMPI project at ${MPI_DIR}"
    MPI_ARGS=(-DMPI_HOME="${MPI_DIR}")
fi

args=(
    -DCMAKE_BUILD_TYPE=Release
    -DCMAKE_CUDA_COMPILER=nvcc
    -DCMAKE_CUDA_ARCHITECTURES="${CUDAARCHS}"

    -DAMReX_GPU_BACKEND=CUDA
    -DAMReX_SPACEDIM=3

    # Embedded Python is only used to plot some test problems' results.
    -DQUOKKA_PYTHON=OFF
    -DPython3_EXECUTABLE="$(realpath venv/bin/python)"
    -GNinja
)

cmake "${args[@]}" "${MPI_ARGS[@]}" -B build -S quokka

# -k 0: build as much as possible, for more signal on what's unsupported.
ninja -C build -k 0
