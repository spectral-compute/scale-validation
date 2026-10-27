#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh

MPI_DIR="$(realpath ../)/openmpi/install"
if [ ! -e "${MPI_DIR}" ]; then
    echo "Please build the OpenMPI third party project first. Use the same working directory." 1>&2
    exit 1
fi

# hypre's configure only looks for MPI compiler wrappers (mpicc, ...) and
# doesn't fall back to cc, so use the ones from our OpenMPI.
export PATH="${MPI_DIR}/bin:${PATH}"
export LD_LIBRARY_PATH="${MPI_DIR}/lib:${LD_LIBRARY_PATH:-}"

# In-tree build, because the CMake build system builds fewer of the test drivers.
# The build only needs src/, so leave .git out of the copy. Start from a fresh
# copy each time, since `cp -r` into an existing directory would nest it.
rm -rf build
mkdir build
cp -r hypre/src build/src

# benchmark.py builds with native HIP too (see benchmarks/).
if [[ "${BENCHMARK_COMPILER:-}" == "hip" ]]; then
    args=(--with-hip --with-gpu-arch="${TEST_GPU_ARCH}")

    # hypre compiles HIP with -std=c++14, but ROCm 7's rocPRIM needs C++17.
    # Flags in HIPCXXFLAGS come after hypre's own, so this one wins.
    export HIPCXXFLAGS="${HIPCXXFLAGS:-} -std=c++17"

    # ROCm's clang searches its own headers last (-idirafter), so a stray
    # distro HIP in /usr/include (e.g. Ubuntu's libamdhip64-dev) wins. Only
    # then, put the toolkit's headers first (never -isystem /usr/include).
    rocm_include="$(realpath "${ROCM_PATH:-/opt/rocm}/include")"
    if [[ -d /usr/include/hip && "${rocm_include}" != "/usr/include" ]]; then
        log "Preferring ${rocm_include} over /usr/include/hip"
        export HIPCXXFLAGS="-isystem${rocm_include} ${HIPCXXFLAGS:-}"
    fi
else
    args=(--with-cuda --with-gpu-arch="${CUDAARCHS}")
fi

# The tests use unified memory, like upstream's CUDA CI. Upstream benchmarks
# without it, so benchmarks/01-build.sh turns it off.
if [[ "${HYPRE_UNIFIED_MEMORY:-1}" == "1" ]]; then
    args+=(--enable-unified-memory)
fi

args+=(
    --disable-onemklsparse
    --disable-onemklblas
    --disable-onemklrand

    --with-MPI-include="${MPI_DIR}/include"
    --with-MPI-libs="mpi"
    --with-MPI-lib-dirs="${MPI_DIR}/lib"
)
# For experiments, e.g. HYPRE_EXTRA_CONFIGURE_ARGS="--disable-cusparse".
# shellcheck disable=2206
args+=(${HYPRE_EXTRA_CONFIGURE_ARGS:-})

(
    cd "build/src"
    ./configure "${args[@]}"
    make test -j"$(nproc)" -O
)
