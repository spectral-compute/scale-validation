#!/bin/bash
#
# Re-run 05-validate.sh's channel case on 2 MPI ranks, so more than one GPU is
# actually driven.
#
# 05-validate.sh runs the solver on a single rank, which leaves every GPU but the
# first idle. cs_base_cuda_select_default_device() picks a rank's device with
#
#   device_id = cs_glob_node_rank_id*n_devices / cs_glob_node_n_ranks
#
# (cs_base_cuda.cu:751), so a single rank always lands on device 0. cs_solver is
# the only binary in this project that reaches that mapping correctly: it calls
# cs_base_mpi_init (cs_solver.cxx:707), which is what populates
# cs_glob_node_rank_id / cs_glob_node_n_ranks, via MPI_Comm_split_type over
# MPI_COMM_TYPE_SHARED (cs_base.cpp:1037). cs_gpu_test has its own private
# _mpi_init that skips that, so running *it* under mpiexec would still put every
# rank on device 0.
#
# What this covers that the single-rank run does not: the domain is partitioned,
# so halo exchange crosses between two devices, and this Open MPI is CUDA-aware
# (mca_accelerator_cuda probes every buffer through SCALE's
# cuMemRetainAllocationHandle), so device pointers reach the MPI collectives.
#
# Note on what is *not* asserted: code_saturne only ever logs the device
# enumeration, never which device a rank selected, so the one-GPU-per-rank split
# cannot be checked from its output. It was confirmed out of band via
# /sys/class/kfd/kfd/proc/<pid>/vram_<gpu_id>, which showed the two cs_solver
# processes holding VRAM on gpu_id 62449 (0000:79:00.0) and 56281
# (0000:19:00.0) -- one each, and never on the third, non-gfx1100 GPU. A KFD
# check would not survive this suite's NVIDIA mode, so what is asserted here is
# that the partitioned multi-device run still dispatches to the GPU and
# reproduces the single-rank answer.

set -ETeuo pipefail

source "$(dirname "$0")"/../util/checks.sh

# Two ranks is the minimum that partitions the domain and, on a multi-GPU node,
# the minimum that drives a second device.
ranks="${CS_RUN_MPI_RANKS:-2}"

cs_install_dir="$(realpath code_saturne-install)"
export PATH="${cs_install_dir}/bin:${PATH}"

# 03-build.sh configured against the openmpi project's install, so mpiexec has
# to be the one from there: "code_saturne run" launches the solver through it.
OUT_DIR=$(realpath ../)
export PATH="${OUT_DIR}/openmpi/install/bin:${PATH}"
export LD_LIBRARY_PATH="${OUT_DIR}/openmpi/install/lib:${LD_LIBRARY_PATH:-}"

# cs_sles_solve_ccc_fv allocates extended solver buffers as CS_ALLOC_DEVICE
# (device-only), then passes them to the CPU convergence check, causing SIGSEGV.
# Setting CS_CUDA_ALLOC_DEVICE_UVM remaps cs_alloc_mode_device to
# CS_ALLOC_HOST_DEVICE_SHARED at init time, which avoids the crash.
# See cs_base_cuda.cu:777.
#
# That remap puts every solver buffer in host-device shared memory, which is
# slow for the iterative solvers. Set CS_DISABLE_DEVICE_UVM=1 to drop the
# workaround, both to measure that cost and to re-check whether the SIGSEGV is
# still there. cs_base_cuda.cu only tests whether the variable is *set* -- it
# atoi()s the value into a variable it never reads -- so unsetting it is the
# only way to turn the remap off: CS_CUDA_ALLOC_DEVICE_UVM=0 still enables it.
if [ -n "${CS_DISABLE_DEVICE_UVM:-}" ]; then
    unset CS_CUDA_ALLOC_DEVICE_UVM
else
    export CS_CUDA_ALLOC_DEVICE_UVM=1
fi

export SHELL=/bin/bash

case_dir="Validation/channel"
if [ ! -d "${case_dir}" ]; then
    echo "Error: ${case_dir} not found -- run 05-validate.sh first." >&2
    exit 1
fi

# Rank count a finished result was produced with. code_saturne omits the
# "MPI ranks:" line from performance.log entirely for a serial run, so a missing
# line means one rank.
resu_ranks() {
    local n
    n="$(sed -n 's/^ *MPI ranks: *\([0-9][0-9]*\).*/\1/p' "$1/performance.log" 2>/dev/null | head -1)"
    echo "${n:-1}"
}

# The baseline is 05-validate.sh's single-rank result. Picked by *being* serial
# rather than by being newest, so re-running this script compares against the
# serial run again instead of silently diffing against its own last output.
baseline_resu=""
pre_newest=""
while IFS= read -r d; do
    pre_newest="${d}"
    [ -s "${d}/residuals.csv" ] || continue
    [ "$(resu_ranks "${d}")" = "1" ] && baseline_resu="${d}"
done < <(ls -1d "${case_dir}"/RESU/*/ 2>/dev/null | sort)

if [ -z "${baseline_resu}" ]; then
    echo "Error: no completed single-rank result in ${case_dir}/RESU -- run 05-validate.sh first." >&2
    exit 1
fi
echo "single-rank baseline: ${baseline_resu}"

# Not allowed to fail the script: a solver that ran and then died still has a
# result directory worth reporting on, and letting the checks below do that
# gives one line per broken claim instead of a bare errexit abort.
(cd "${case_dir}" && code_saturne run -n "${ranks}") 2>&1 | tee run-mpi.log || true

resu_dir="$(ls -1d "${case_dir}"/RESU/*/ | sort | tail -1)"
# Without a fresh directory there is nothing to judge, and falling through would
# compare the baseline against itself and report a meaningless pass.
if [ "${resu_dir}" = "${pre_newest}" ]; then
    echo "Error: no new result directory appeared under ${case_dir}/RESU." >&2
    exit 1
fi
echo "multi-rank result:    ${resu_dir}"

solver_log="${resu_dir}/run_solver.log"

# The launcher reports the rank count it actually used, which is what confirms
# the run was parallel rather than silently falling back to serial.
check_rank_count() {
    grep -q "Parallel code_saturne on ${ranks} processes" run-mpi.log
}

check_completed() {
    [ -s "${solver_log}" ] || {
        echo "no run_solver.log in ${resu_dir}" >&2
        return 1
    }
    grep -q "END OF CALCULATION" "${solver_log}"
}

# Same GPU-dispatch evidence 05-validate.sh checks: without this the run could have
# completed entirely on the CPU and still looked fine.
check_gpu_dispatch() {
    grep -q "Selected device SpMV variant" "${resu_dir}/performance.log"
}

# Partitioning changes the order of the global reductions, so the residuals
# shift slightly; measured agreement on this case is exact for velocity/k/
# epsilon and ~3e-5 relative for pressure. A broken halo exchange or a device
# that never received its data lands orders of magnitude out, or non-finite.
check_matches_baseline() {
    [ -s "${resu_dir}/residuals.csv" ] || {
        echo "no residuals.csv in ${resu_dir}" >&2
        return 1
    }
    awk -F, -v tol=1e-3 -v ranks="${ranks}" '
        FNR == 1 { file++ }
        { last[file] = $0 }
        END {
            n1 = split(last[1], A, ",");
            n2 = split(last[2], B, ",");
            if (n1 < 2 || n1 != n2) {
                printf "residual column count differs: %d vs %d\n", n1, n2;
                exit 1;
            }
            bad = 0;
            for (i = 1; i <= n1; i++) {
                if (tolower(B[i]) ~ /nan|inf/) {
                    printf "  col %d: non-finite (%s)\n", i, B[i];
                    bad++;
                    continue;
                }
                x = A[i] + 0; y = B[i] + 0;
                rel = (x != 0) ? (y - x) / x : (y - x);
                if (rel < 0) rel = -rel;
                ok = (rel <= tol);
                printf "  %-3s col %d: 1-rank=%-14g %d-rank=%-14g rel=%.3e\n",
                       (ok ? "ok" : "BAD"), i, x, ranks, y, rel;
                if (!ok) bad++;
            }
            printf "%d/%d residual columns within %g relative\n", n1 - bad, n1, tol;
            exit (bad > 0);
        }' "${baseline_resu}/residuals.csv" "${resu_dir}/residuals.csv"
}

check "solver ran on ${ranks} MPI ranks"          check_rank_count
check "calculation completed"                     check_completed
check "GPU solver dispatched"                     check_gpu_dispatch
check "residuals match single-rank baseline"      check_matches_baseline

check_exit
