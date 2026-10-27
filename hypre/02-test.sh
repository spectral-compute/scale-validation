#!/usr/bin/env bash
# shellcheck disable=2329
. "$(dirname "$0")"/../util/prelude.sh

source "$SCALE_VALIDATION/util/checks.sh"

MPI_DIR="$(realpath ../openmpi/install)"
export PATH="${MPI_DIR}/bin:${PATH}"
export LD_LIBRARY_PATH="${MPI_DIR}/lib:${LD_LIBRARY_PATH:-}"
export OMPI_MCA_accelerator=cuda
# Some jobs use more ranks than a CI runner has cores.
export OMPI_MCA_rmaps_base_oversubscribe=1

cd build/src/test

# Run one group of hypre's regression tests. runtest.sh exits 0 even when tests
# fail: it records each failure (stderr output, or a mismatch against the saved
# baseline) in a non-empty <test>.err file, so check for those ourselves.
#
# Outputs are compared against the CUDA baselines (*.saved.lassen), with the
# looser tolerances upstream uses when results aren't bit-for-bit reproducible.
run_group() {
    local group="$1" pattern="${2:-*.sh}"
    local scripts errs f
    # shellcheck disable=2206
    scripts=("${group}"/${pattern})

    rm -f "${group}"/*.err "${group}"/*.err.*
    ./runtest.sh -t -mpi "$(command -v mpirun) -np" \
        -save lassen -rtol 1e-2 -atol 1e-6 "${scripts[@]}" || return 1

    errs="$(find "${group}" -maxdepth 1 -name '*.err' -size +0 | sort)"
    [ -z "${errs}" ] && return 0
    for f in ${errs}; do
        echo "==> ${f}"
        head -n 40 "${f}"
    done
    return 1
}

# The groups upstream's CI runs on a `--with-cuda --enable-unified-memory`
# build (AUTOTEST/machine-lassen.sh). TEST_ij's fsai tests are excluded there
# too. Not run here:
# - TEST_bench, TEST_timing: performance, see benchmarks/.
# - TEST_single, TEST_longdouble, TEST_superlu, TEST_fei, TEST_error: each needs
#   a differently configured build (precision, SuperLU_DIST, FEI, print-errors).
# - TEST_gpumemcheck: needs NVIDIA's compute-sanitizer.
# - TEST_fac, TEST_lobpcg, TEST_examples: not run by upstream on GPU builds.
check "ij" run_group TEST_ij '[^f]*.sh'
check "ams" run_group TEST_ams
check "struct" run_group TEST_struct
check "sstruct" run_group TEST_sstruct
check_exit
