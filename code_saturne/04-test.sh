#!/bin/bash
#
# Run code_saturne's unit test suite: the programs under tests/.
#
# 01-patch.sh switches on automake's test harness in tests/Makefile.am
# (upstream ships it disabled), so "make check" builds and runs the tests,
# reports PASS/FAIL per test, and captures each one's output to
# tests/<name>.log. bft_error_test is declared XFAIL there -- it is meant to
# terminate. 01-patch.sh also carries the fixes for the three upstream bugs
# that the harness then trips over.
#
# Exit status isn't the whole story though: cs_gpu_test prints its numerical
# results and then exits 0 unconditionally, so automake reports PASS even if
# every CUDA reduction returned garbage. Checking that output is the part that
# actually validates SCALE.

set -Eeuo pipefail

source "$(dirname "$0")"/../util/checks.sh

if [ ! -d code_saturne/build/tests ]; then
    echo "Error: code_saturne/build/tests not found -- run 03-build.sh first." >&2
    exit 1
fi
tests_dir="$(realpath code_saturne/build/tests)"
src_tests_dir="$(realpath code_saturne/tests)"

# 03-build.sh configured against the openmpi project's install, so the
# MPI-aware tests below have to launch through that mpiexec.
OUT_DIR=$(realpath ../)
export PATH="${OUT_DIR}/openmpi/install/bin:${PATH}"
export LD_LIBRARY_PATH="${OUT_DIR}/openmpi/install/lib:${LD_LIBRARY_PATH:-}"

# How many ranks the MPI-aware tests get. Two is enough to make every
# all-to-all, interface and rank-neighbour path actually exchange something;
# one rank leaves them trivially satisfied.
mpi_ranks="${CS_TEST_MPI_RANKS:-2}"

# Only a backstop against a hung kernel: the suite legitimately takes minutes
# (cs_blas_test and cs_gpu_test self-time at ~1s per variant per size).
timeout_s="${CS_TEST_TIMEOUT:-1800}"

# Stale results would otherwise survive a program that stopped building.
rm -f "${tests_dir}"/*.trs "${tests_dir}"/*.log

# Which programs initialise MPI, and so are worth launching under mpiexec: they
# are the ones calling cs_base_mpi_init, which only calls MPI_Init when it
# detects a launcher (OMPI_COMM_WORLD_RANK and friends -- see cs_base.cpp).
# Grepped rather than listed so the split tracks upstream, and intersected with
# what was actually built (cs_gpu_hip_test only exists for HIP builds).
mpi_test_names() {
    local t
    for t in $(cd "${src_tests_dir}" && grep -l cs_base_mpi_init ./*.cpp \
                   | sed -e 's|^\./||' -e 's|\.cpp$||' | sort); do
        [ -x "${tests_dir}/${t}" ] && echo "${t}"
    done
}

# Run one "make check" pass over an explicit TESTS list. Each pass rewrites
# test-suite.log, so a failing pass has to be dumped before the next one runs.
run_pass() {
    local label="$1" launcher="$2"
    shift 2
    make -C "${tests_dir}" -k check TESTS="$*" \
        LOG_COMPILER=timeout AM_LOG_FLAGS="${timeout_s} ${launcher}" \
        || { echo "--- ${label} test-suite.log ---";
             cat "${tests_dir}/test-suite.log"; return 1; }
}

# Every test program that got built, MPI-aware or not. Derived from the sources
# and filtered by "was it built", so conditional programs (cs_gpu_test needs
# HAVE_ACCEL, cs_gpu_hip_test needs HIP) sort themselves out.
built_test_names() {
    local t
    for t in $(cd "${src_tests_dir}" && ls ./*.cpp \
                   | sed -e 's|^\./||' -e 's|\.cpp$||' | sort); do
        [ -x "${tests_dir}/${t}" ] && echo "${t}"
    done
}

# Everything that does not initialise MPI stays serial. Putting it under
# mpiexec would run each program once per rank for no added coverage, and have
# both copies race the fixed-name files some of them write (bft_mem_log_file).
run_serial_tests() {
    local mpi serial t
    mpi="$(mpi_test_names)"
    serial=""
    for t in $(built_test_names); do
        grep -qxF -- "${t}" <<< "${mpi}" || serial="${serial} ${t}"
    done
    run_pass serial "" ${serial}
}

run_mpi_tests() {
    local mpi
    mpi="$(mpi_test_names)"
    if [ -z "${mpi}" ]; then
        echo "Error: no MPI-aware tests found; the cs_base_mpi_init grep is stale." >&2
        return 1
    fi
    echo "running under ${mpi_ranks} ranks:" ${mpi}
    run_pass "mpi" "mpiexec -n ${mpi_ranks}" ${mpi}
}

# cs_gpu_test dots x.y for synthetic vectors whose exact sum is 165*(n/10)*pi,
# once per CUDA reduction variant (two-stage, forced unroll, warp shuffle, block
# atomics, cuBLAS, cooperative groups), and prints how far off each one was:
#
#   CUDA dot product X.Y 2-stage, forced unroll (1000000 elts., 4.66e-09 err)
#
# A correct reduction lands at ~1e-16 relative, a miscompiled one at ~1e0. This
# also covers "the GPU path never ran at all" -- no device, no such lines.
# Variant names contain spaces and commas, so the numbers are read from the end.
#
# Counting the results matters as much as checking them: cs_gpu_test aborts on
# the first CUDA error, so a crash part-way leaves a log whose surviving lines
# are all accurate. Judging only those reports a pass on however little ran --
# it once passed on 1 of 36 variants while the test was dying with "invalid
# device". The expected count is the variant list times the size list, both
# read out of the test's own source so upstream can change them.
expected_dot_results() {
    local src variants sizes
    src="${src_tests_dir}/cs_gpu_cuda_test.cu"
    variants=$(sed -n '/const char \*dot_name\[\] *= *{/,/}/p' "${src}" | grep -c '"')
    sizes=$(sed -n 's/.*_n_sizes *= *\([0-9][0-9]*\).*/\1/p' "${src}" | head -1)
    if [ -n "${sizes}" ] && [ "${variants}" -gt 0 ] && [ "${sizes}" -gt 0 ]; then
        echo $((variants * sizes))
    else
        echo 0   # could not parse; check_dot_accuracy then only checks accuracy
    fi
}

check_dot_accuracy() {
    awk -v tol=1e-9 -v expected="$(expected_dot_results)" '
        /^CUDA dot product X\.Y/ {
            n = $(NF-3); gsub(/[()]/, "", n);
            raw_err = $(NF-1);
            err = raw_err + 0; if (err < 0) err = -err;
            ref = 165 * int(n / 10) * atan2(0, -1);
            rel = err / ref;
            nonfinite = (tolower(raw_err) ~ /nan|inf/);
            ok = (!nonfinite && rel <= tol);
            printf "  %-3s %-20s %s\n", (ok ? "ok" : "BAD"),
                   (nonfinite ? "non-finite" : sprintf("rel.err %9.3e", rel)), $0;
            total++; if (!ok) bad++;
        }
        END {
            if (total == 0) { print "no CUDA dot product results: the GPU path did not run"; exit 1 }
            printf "%d/%d variants within %g relative error\n", total - bad, total, tol;
            if (expected > 0 && total < expected) {
                printf "only %d of %d expected results: cs_gpu_test stopped early\n",
                       total, expected;
                exit 1;
            }
            exit (bad > 0);
        }' "${tests_dir}/cs_gpu_test.log"
}

# Built in parallel, then run serially ("TESTS=" empties the test list, so the
# first invocation only compiles): several GPU tests at once on the one device
# is a good way to manufacture flaky OOMs.
check "build unit tests" make -C "${tests_dir}" -k -j"$(nproc)" check TESTS=
check "run unit tests"   run_serial_tests
check "run unit tests (${mpi_ranks} MPI ranks)" run_mpi_tests
check "cs_gpu_test: CUDA dot products accurate" check_dot_accuracy

check_exit
