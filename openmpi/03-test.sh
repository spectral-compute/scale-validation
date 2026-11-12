#!/usr/bin/env bash
# Check that this Open MPI is CUDA-aware on top of the toolkit under test, using
# the OSU micro-benchmarks with device buffers (-d cuda) and data validation
# (-c). A benchmark that sees corrupted data prints "DATA VALIDATION ERROR" and
# exits non-zero.
#
# One-sided benchmarks aren't run: Open MPI 5 without UCX can't create windows
# on device memory.
#
# OMB is built here rather than in the build stage, because projects that only
# need Open MPI as a dependency (FastEddy, hypre, ...) also run that stage.

. "$(dirname "$0")"/../util/prelude.sh
. "$(dirname "$0")"/../util/checks.sh

MPI_INSTALL_DIR="$(realpath ../)/openmpi/install"
export PATH="${MPI_INSTALL_DIR}/bin:${PATH}"
export LD_LIBRARY_PATH="${MPI_INSTALL_DIR}/lib:${LD_LIBRARY_PATH:-}"

OMB_VER="$(get_version osu-micro-benchmarks)"
OMB_DIR="osu-micro-benchmarks-${OMB_VER}"
OMB_INSTALL_DIR="$(realpath .)/omb"
if [ ! -d "${OMB_DIR}" ]; then
    wget "https://mvapich.cse.ohio-state.edu/download/mvapich/${OMB_DIR}.tar.gz"
    tar -xf "${OMB_DIR}.tar.gz"
fi
# Basic CUDA support: the kernels are only for compute overlap and managed
# memory, neither tested here, and are built with `nvcc -cuda`, which SCALE's nvcc doesn't support.
# --with-cuda would turn the kernels back on, so give the paths separately.
(
    cd "${OMB_DIR}"
    ./configure CC=mpicc CXX=mpicxx --enable-cuda=basic \
        --with-cuda-include="${CUDA_PATH}/include" --with-cuda-libpath="${CUDA_PATH}/lib" \
        --prefix="${OMB_INSTALL_DIR}"
    make -j"$(nproc)" install
)
OMB="${OMB_INSTALL_DIR}/libexec/osu-micro-benchmarks/mpi"

# Fail loudly if the CUDA accelerator component can't be used, instead of
# silently treating device pointers as host memory.
export OMPI_MCA_accelerator=cuda

mpirun_args=(-np 2)
if [ "$(id -u)" = "0" ]; then
    mpirun_args+=(--allow-run-as-root)
fi

# Run one benchmark on two ranks. A hang counts as a failure. The message sizes
# are what matter for coverage, so the iteration counts are cut well below the
# defaults, which take over ten minutes in all.
omb() {
    timeout 600 mpirun "${mpirun_args[@]}" "${OMB}/$1" -i 100 -x 10 "${@:2}"
}

check_accelerator_cuda() {
    mpirun "${mpirun_args[@]}" --mca accelerator_base_verbose 100 \
        "${OMB}/pt2pt/osu_latency" -d cuda -m 1:1 -i 1 -x 0 D D >accelerator.log 2>&1
    grep -Eiq 'selected.*cuda' accelerator.log || {
        grep -i accelerator accelerator.log >&2
        return 1
    }
}
check "CUDA accelerator component selected" check_accelerator_cuda

# Point-to-point, with every placement of the two buffers. The default sizes go
# up to 4MiB, past the eager limit, so this covers the rendezvous path too.
for bench in osu_latency osu_bw osu_bibw; do
    for bufs in "D D" "H D" "D H"; do
        # shellcheck disable=SC2086
        check "${bench} ${bufs}" omb "pt2pt/${bench}" -c -d cuda ${bufs}
    done
done

for bench in osu_allreduce osu_reduce osu_bcast osu_allgather osu_alltoall; do
    check "${bench}" omb "collective/${bench}" -c -d cuda
done

check_exit
