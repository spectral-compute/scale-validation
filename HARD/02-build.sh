#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh

PREFIX="$(realpath .)/install"

MPI_ARGS=()
MPI_DIR="$(realpath ../)/openmpi/install"
if [ -e "${MPI_DIR}" ]; then
    MPI_ARGS=(-DMPI_HOME="${MPI_DIR}")
fi

if [[ "${BENCHMARK_COMPILER:-}" == hip ]]; then
    COMPILER_ARGS=(-DCMAKE_CXX_COMPILER="${ROCM_PATH}/llvm/bin/clang++" -DCMAKE_C_COMPILER="${ROCM_PATH}/llvm/bin/clang")
else
    COMPILER_ARGS=(-DCMAKE_CXX_COMPILER=clang++ -DCMAKE_C_COMPILER=clang -DCMAKE_CXX_FLAGS="-DSCALE_WARP_SIZE=32")
fi

args=(
    -DCMAKE_BUILD_TYPE=Release
    # C++20, but no modules (and ROCm has no clang-scan-deps).
    -DCMAKE_CXX_SCAN_FOR_MODULES=OFF
    "${COMPILER_ARGS[@]}"
    -DCMAKE_PREFIX_PATH="${PREFIX}"
    -Dpybind11_DIR="$(venv/bin/python -m pybind11 --cmakedir)"
    -DPython_EXECUTABLE="${PWD}/venv/bin/python"
    -DPython3_EXECUTABLE="${PWD}/venv/bin/python"
    -DENABLE_UNIT_TESTS=ON
    -DENABLE_VERIFICATION=ON
    # No I/O, and per-cycle timings: see benchmarks/03-benchmark.sh.
    -DHARD_BENCHMARK_MODE="${HARD_BENCHMARK_MODE:-OFF}"
)

# Not Ninja: the verification tests run `make verify CONFIG=...` in the build directory.
BUILD_DIR="${HARD_BUILD_DIR:-build}"
cmake "${args[@]}" "${MPI_ARGS[@]}" -B "${BUILD_DIR}" -S HARD

make -C "${BUILD_DIR}" -j"$(nproc)"
