#!/usr/bin/env bash
#
# Paths and environment shared by the code_saturne scripts. It's a .bash rather
# than a .sh so that neither test.sh nor benchmark.py runs it as a step.
#
# Every script runs from the project's workdir, <workdir>/code_saturne.

# shellcheck disable=SC2034 # used by the scripts that source this

# Built by 02-build-deps.sh: HDF5, MED and CGNS, so the preprocessor can read
# the .med and .cgns meshes the tutorials ship.
DEPS_INSTALL="${PWD}/deps-install"

# Built by 03-build.sh (or benchmarks/03-build-hip.sh).
CS_INSTALL="${PWD}/code_saturne-install"

# The openmpi project's install, built against the CUDA toolkit under test.
# Run that project in the same workdir first.
OPENMPI_INSTALL="$(dirname "${PWD}")/openmpi/install"

# Put an Open MPI install on PATH, so that configure finds its mpiexec and
# "code_saturne run" launches through it.
use_openmpi() {
    local mpi_dir="${1:-${OPENMPI_INSTALL}}"
    if [[ ! -x "${mpi_dir}/bin/mpiexec" ]]; then
        echo "Error: no Open MPI in ${mpi_dir}. Build the openmpi project first, in the same workdir." >&2
        return 1
    fi
    export PATH="${mpi_dir}/bin:${PATH}"
    export LD_LIBRARY_PATH="${mpi_dir}/lib:${LD_LIBRARY_PATH:-}"
}

use_code_saturne() {
    export PATH="${CS_INSTALL}/bin:${PATH}"
    export SHELL=/bin/bash
}

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
use_device_uvm_workaround() {
    if [[ -n "${CS_DISABLE_DEVICE_UVM:-}" ]]; then
        unset CS_CUDA_ALLOC_DEVICE_UVM
    else
        export CS_CUDA_ALLOC_DEVICE_UVM=1
    fi
}

# prterun binds each rank to a single core by default (Cpus_allowed_list ends up
# as one core plus its SMT sibling), and SCALE runs ~7 threads per process --
# the application thread, {Scheduler}, four {Host queue}s and {GPU trap mon} --
# which all inherit that mask. Giving the ranks room to run those threads is
# worth ~25% on 05_Mixing_Tee, so ask for it.
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
use_numa_binding() {
    export PRTE_MCA_rmaps_default_mapping_policy=numa
    export PRTE_MCA_hwloc_default_binding_policy=numa
}

# The GPU indices this run may use, one per line: the -d/--device list that
# benchmark.py exports if there is one, else every GPU on the node.
visible_gpus() {
    local devices="${CUDA_VISIBLE_DEVICES:-${HIP_VISIBLE_DEVICES:-}}"

    if [[ -n "${devices}" ]]; then
        tr ',' '\n' <<<"${devices}"
    elif [[ -d /sys/class/kfd/kfd/topology/nodes ]]; then
        # KFD lists the CPUs as nodes too; only GPUs have SIMDs. ROCm numbers
        # the GPUs in node order.
        local nodes=/sys/class/kfd/kfd/topology/nodes node index=0
        for node in $(cd "${nodes}" && printf '%s\n' * | sort -n); do
            if grep -q '^simd_count [1-9]' "${nodes}/${node}/properties"; then
                echo "${index}"
                index=$((index + 1))
            fi
        done
    elif command -v nvidia-smi >/dev/null; then
        nvidia-smi --query-gpu=index --format=csv,noheader
    fi
}
