#!/bin/bash
#
# Build the Open MPI test suite against the Open MPI installed by 02-build.sh
# and run it, so this project has a correctness signal of its own. Until now it
# was only ever exercised indirectly, through the projects that link against it
# (code_saturne, gromacs, ...), which means a broken Open MPI surfaced as a
# confusing failure somewhere else.
#
# Two independent claims are checked:
#
#   1. The runtime actually selects the CUDA accelerator component. This is the
#      failure mode 01-configure.sh's --with-pmix/--with-prrte comment
#      describes: when something overrides Open MPI's component path, no DSO
#      component loads, the accelerator framework falls back to "null", and
#      every device pointer handed to MPI is treated as host memory. Nothing
#      else here would notice -- the build still succeeds and the suite below,
#      being host-buffer only, still passes.
#
#   2. The suite reports no failed tests. mpi_test_suite runs its whole
#      test x communicator x datatype matrix inside a single MPI_Init (that is
#      its design -- one binary, since MPI_Init/MPI_Finalize are expensive),
#      prints "Number of failed tests: N" from rank 0, and exits non-zero when
#      N > 0.
#
# The suite itself contains no CUDA at all: it validates that this Open MPI
# works, not that it is CUDA-aware. Check 1 is what covers the CUDA-aware half,
# as far as that can be covered without device buffers in the suite.

set -ETeuo pipefail

source "$(dirname "$0")"/../util/checks.sh
source "$(dirname "$0")"/../util/git.sh

OUT_DIR="$(realpath ../)"
MPI_INSTALL_DIR="${OUT_DIR}/openmpi/install"

export PATH="${MPI_INSTALL_DIR}/bin:${PATH}"
export LD_LIBRARY_PATH="${MPI_INSTALL_DIR}/lib:${LD_LIBRARY_PATH:-}"

# 00-clone.sh already cloned this; re-cloning when it is missing keeps the
# script runnable on its own against an existing build.
if [ ! -d mpi-test-suite ]; then
    do_clone mpi-test-suite https://github.com/open-mpi/mpi-test-suite.git main
fi

# cmdline.c/h are generated from cmdline.ggo at make time and are not in the
# upstream repo, so this build needs gengetopt even though nothing else does.
# Checked up front because the failure otherwise lands mid-make as a missing
# source file, which reads like a broken checkout.
if ! command -v gengetopt >/dev/null; then
    echo "Error: gengetopt is required to build mpi-test-suite (apt install gengetopt)." >&2
    exit 1
fi

# Two ranks is the minimum that makes the P2P and collective tests meaningful
# (a ring needs a neighbour). Raise it to widen the collective coverage; the
# suite accepts an arbitrary rank count.
ranks="${MPI_TEST_RANKS:-2}"

(cd mpi-test-suite && autoreconf -i)
mkdir -p mpi-test-suite/build
# Out-of-source, like the Open MPI build itself. gengetopt's Makefile rule
# writes cmdline.c/h into the build directory, so VPATH is fine here.
(cd mpi-test-suite/build && ../configure CC=mpicc && make -j"$(nproc)")

suite="$(realpath mpi-test-suite/build/mpi_test_suite)"

# --oversubscribe: the rank count is chosen for coverage, not for the machine,
# and CI runners can have fewer slots than that. --allow-run-as-root only when
# needed: containers here run as root, and mpirun refuses by default.
mpirun_args=(-np "${ranks}" --oversubscribe)
if [ "$(id -u)" = "0" ]; then
    mpirun_args+=(--allow-run-as-root)
fi

# Smallest run that still goes through MPI_Init, which is where the accelerator
# framework picks its component -- one test, one communicator, one value.
check_accelerator_cuda() {
    mpirun "${mpirun_args[@]}" --mca accelerator_base_verbose 100 \
        "${suite}" -t Status -c MPI_COMM_WORLD -n 1 > accelerator.log 2>&1 || true

    if grep -Eiq 'select.*accelerator.*cuda|selected component.*cuda' accelerator.log; then
        return 0
    fi

    echo "CUDA accelerator component was not selected; accelerator framework said:" >&2
    grep -i accelerator accelerator.log | head -20 >&2
    return 1
}

# Not allowed to fail the script: a run that started and then died still has
# output worth reporting on, and the checks below turn that into one line per
# broken claim instead of a bare errexit abort.
set +e
mpirun "${mpirun_args[@]}" "${suite}" -r summary 2>&1 | tee suite.log
suite_status="${PIPESTATUS[0]}"
set -e
echo "mpi_test_suite exit status: ${suite_status}"

# A run killed partway through (a rank calling MPI_Abort, or the launcher giving
# up) never reaches rank 0's summary, so the line's presence is what separates
# "ran and found failures" from "never finished".
check_suite_completed() {
    grep -q "Number of failed tests:" suite.log
}

check_no_failed_tests() {
    grep -q "Number of failed tests: 0" suite.log || {
        echo "failing combinations:" >&2
        grep "^ERROR class:" suite.log | head -20 >&2
        return 1
    }
    [ "${suite_status}" -eq 0 ]
}

check "CUDA accelerator component selected"       check_accelerator_cuda
check "test suite ran to completion"              check_suite_completed
check "no failed tests on ${ranks} ranks"         check_no_failed_tests

check_exit
