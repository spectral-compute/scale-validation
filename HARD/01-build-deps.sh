#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh

PREFIX="$(realpath .)/install"

# pybind11 for HARD's Python configuration files; the rest is for the verification tests.
python3 -m venv venv
venv/bin/pip install numpy scipy matplotlib pybind11 \
    "git+https://github.com/lanl/exactpack.git@$(get_version HARD-exactpack)"

(
    cd boost
    ./bootstrap.sh --with-libraries=program_options --prefix="${PREFIX}"
    ./b2 -j"$(nproc)" install
)

COMMON_ARGS=(
    -DCMAKE_BUILD_TYPE=Release
    # C++20, but no modules (and ROCm has no clang-scan-deps).
    -DCMAKE_CXX_SCAN_FOR_MODULES=OFF
    -DCMAKE_INSTALL_PREFIX="${PREFIX}"
    -DCMAKE_PREFIX_PATH="${PREFIX}"
    # Kokkos is static, but ends up in FleCSI's shared library.
    -DCMAKE_POSITION_INDEPENDENT_CODE=ON
    -GNinja
)

if [[ "${BENCHMARK_COMPILER:-}" == hip ]]; then
    # Native ROCm baseline for benchmark.py.
    COMMON_ARGS+=(-DCMAKE_CXX_COMPILER="${ROCM_PATH}/llvm/bin/clang++" -DCMAKE_C_COMPILER="${ROCM_PATH}/llvm/bin/clang")
    KOKKOS_ARGS=(-DKokkos_ENABLE_HIP=ON "-DKokkos_ARCH_AMD_${TEST_GPU_ARCH^^}=ON")
    SINGULARITY_GPU_ARGS=()
else
    # Kokkos wants a named architecture rather than a compute capability.
    case "${CUDAARCHS}" in
        70) KOKKOS_ARCH=VOLTA70 ;;
        75) KOKKOS_ARCH=TURING75 ;;
        80) KOKKOS_ARCH=AMPERE80 ;;
        86) KOKKOS_ARCH=AMPERE86 ;;
        89) KOKKOS_ARCH=ADA89 ;;
        90) KOKKOS_ARCH=HOPPER90 ;;
        100) KOKKOS_ARCH=BLACKWELL100 ;;
        120) KOKKOS_ARCH=BLACKWELL120 ;;
        *)
            echo "Unrecognised CUDAARCHS=${CUDAARCHS}; add it to the Kokkos_ARCH mapping in $0" 1>&2
            exit 1
            ;;
    esac

    # FleCSI only supports CUDA through Clang, compiling everything with the CXX compiler.
    # Kokkos assumes 32-wide warps.
    export CXXFLAGS="${CXXFLAGS:-} -DSCALE_WARP_SIZE=32"
    COMMON_ARGS+=(-DCMAKE_CXX_COMPILER=clang++ -DCMAKE_C_COMPILER=clang)
    KOKKOS_ARGS=(-DKokkos_ENABLE_CUDA=ON -DKokkos_ENABLE_CUDA_CONSTEXPR=ON "-DKokkos_ARCH_${KOKKOS_ARCH}=ON")
    SINGULARITY_GPU_ARGS=(-DSINGULARITY_USE_CUDA=ON)
fi

build_dep() {
    local name="$1" src="$2"
    shift 2
    cmake "${COMMON_ARGS[@]}" "$@" -B "build-${name}" -S "${src}"
    ninja -C "build-${name}" install
}

build_dep eigen singularity-eos/utils/eigen -DBUILD_TESTING=OFF -DEIGEN_BUILD_DOC=OFF

build_dep kokkos singularity-eos/utils/kokkos -DKokkos_ENABLE_SERIAL=ON "${KOKKOS_ARGS[@]}"

build_dep ports-of-call singularity-eos/utils/ports-of-call
build_dep spiner singularity-eos/utils/spiner -DSPINER_USE_HDF=ON

# The configuration HARD's Spack package asks for, less EOSPAC (not freely available).
build_dep singularity-eos singularity-eos \
    "${SINGULARITY_GPU_ARGS[@]}" \
    -DSINGULARITY_USE_KOKKOS=ON \
    -DSINGULARITY_USE_SPINER=ON \
    -DSINGULARITY_USE_SPINER_WITH_HDF5=ON \
    -DSINGULARITY_USE_FORTRAN=OFF \
    -DSINGULARITY_BUILD_CLOSURE=OFF

# Prefer the OpenMPI project (built against the toolkit, so GPU-aware) when it has been built in
# the same working directory; otherwise fall back to the system MPI.
MPI_ARGS=()
MPI_DIR="$(realpath ../)/openmpi/install"
if [ -e "${MPI_DIR}" ]; then
    echo "Found OpenMPI project at ${MPI_DIR}"
    MPI_ARGS=(-DMPI_HOME="${MPI_DIR}")
fi

build_dep flecsi flecsi "${MPI_ARGS[@]}" \
    -DFLECSI_BACKEND=mpi \
    -DENABLE_FLOG=ON \
    -DBoost_ROOT="${PREFIX}"

# AMP is for flecsolve's "standard" setup, which HARD's Spack package doesn't use.
build_dep flecsolve flecsolve "${MPI_ARGS[@]}" -DFLECSOLVE_ENABLE_AMP=OFF -DFLECSOLVE_ENABLE_UNIT_TESTS=OFF
