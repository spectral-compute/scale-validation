#!/bin/bash
#
# Run the 05_Mixing_Tee tutorial through studymanager.
#
# Upstream drives this with "code_saturne smgrgui", the Qt front-end, which
# needs an X display and aborts outright without one. "code_saturne smgr" is
# the same studymanager with a command line instead of a GUI, so it works over
# a plain ssh session; -r is what the GUI's "Run" button does.
#
# smgr.xml ships with <repository/> and <destination/> empty -- the GUI fills
# those in from its own fields -- so both have to be passed here. The
# repository is the tutorials checkout holding the study directory; the
# destination is where the cases are copied to and run.

set -ETeuo pipefail

source "$(dirname "$0")"/../util/checks.sh

cs_install_dir="$(realpath code_saturne-install)"
export PATH="${cs_install_dir}/bin:${PATH}"

repo="$(realpath saturne_tutorials)"

# 03-build.sh configured against the openmpi project's install, so mpiexec has
# to be the one from there: studymanager launches the solver through it.
OUT_DIR=$(realpath ../)
export PATH="${OUT_DIR}/openmpi/install/bin:${PATH}"
export LD_LIBRARY_PATH="${OUT_DIR}/openmpi/install/lib:${LD_LIBRARY_PATH:-}"

# prterun binds each rank to a single core by default (Cpus_allowed_list ends up
# as one core plus its SMT sibling), and SCALE runs ~7 threads per process --
# the application thread, {Scheduler}, four {Host queue}s and {GPU trap mon} --
# which all inherit that mask. Giving the ranks room to run those threads is
# worth ~25% here, so ask for it.
#
# Mapping has to be at or above the binding level, so both have to be set --
# binding by numa alone is rejected against the default by-core mapping.
#
# This used to matter enormously rather than marginally. The spin loops in
# Signal.cpp, Scheduler.cpp and JobQueueThread.cpp ran flat out for 1 << 24
# iterations (~4.4ms) without yielding, so with every thread on one core a
# handoff from the application thread to the scheduler thread had to wait for
# Linux to preempt, ~3ms, twice per GPU operation. With CUDA-aware MPI issuing
# ~19k driver-API cuMemcpyAsync calls per time step, 12_Tee_Junction CASE1 on 4
# ranks took 313s for 3 time steps instead of 3.2s. util/SpinWait.hpp now
# pauses and then yields, which fixes that at the source: the same run is 4.3s
# with default binding and 3.3s with the policy below.
export PRTE_MCA_rmaps_default_mapping_policy=numa
export PRTE_MCA_hwloc_default_binding_policy=numa

# cs_sles_solve_ccc_fv allocates extended solver buffers as CS_ALLOC_DEVICE
# (device-only), then passes them to the CPU convergence check, causing SIGSEGV.
# Setting CS_CUDA_ALLOC_DEVICE_UVM remaps cs_alloc_mode_device to
# CS_ALLOC_HOST_DEVICE_SHARED at init time, which avoids the crash.
# See cs_base_cuda.cu:777.
export CS_CUDA_ALLOC_DEVICE_UVM=1

export SHELL=/bin/bash

dest="${CS_SMGR_DEST:-$(realpath .)/saturne_tutorials_run}"
mkdir -p "${dest}"

# The RANS case's setup.xml asks for 3000 iterations; set this to cut a smoke
# test short.
iterations="${CS_SMGR_ITERATIONS:-}"

n_procs="${CS_SMGR_N_PROCS:-4}"

smgr_log="${dest}/smgr_output.log"
smgr_status=0
code_saturne smgr -f "${repo}/05_Mixing_Tee/smgr.xml" \
    --repo="${repo}" --dest="${dest}" \
    --n-procs="${n_procs}" \
    ${iterations:+-n "${iterations}"} \
    -r 2>&1 | tee "${smgr_log}" || smgr_status=$?

check_smgr_exit() {
    [ "${smgr_status}" -eq 0 ]
}

# Guards against a false pass on a destination left over from an earlier run:
# without this, re-running against a populated --dest skips every case and
# still reports success.
check_cases_ran() {
    grep -qE 'run .* --> (OK|FAILED)' "${smgr_log}" &&
        ! grep -qE 'SKIPPED \(already present\)|was cancelled' "${smgr_log}"
}

check_cases_succeeded() {
    ! grep -q -- '--> FAILED' "${smgr_log}"
}

check "studymanager exited cleanly"                check_smgr_exit
check "every case ran (none skipped or cancelled)" check_cases_ran
check "every case completed"                       check_cases_succeeded

check_exit
