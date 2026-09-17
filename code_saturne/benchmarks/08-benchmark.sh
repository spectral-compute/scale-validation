#!/usr/bin/env bash
#
# Time code_saturne's solver at several rank counts, one GPU per rank. This is the same script for every toolchain: SCALE and NVIDIA
# CUDA run the CUDA backend from 03-build.sh, and HIP runs the native HIP port
# from 03-build-hip.sh.
#
# Cases:
#   05_Mixing_Tee/RANS    602,712 cells; the biggest tutorial, but only ~75k
#                         cells per GPU at 8 GPUs, which is too few to scale.
#   12_Tee_Junction/CASE1 12,798 cells; latency-bound, so it mostly measures
#                         kernel launch and synchronisation overhead.
#   UEABS_CAVITY_13M      The PRACE UEABS code_saturne benchmark: a laminar
#   UEABS_CAVITY_111M     lid-driven cavity on 13M tetrahedra, or 111M once
#                         refined (see ueabs_cavity/). Big enough to keep 8
#                         GPUs busy, and 13M on 1 GPU against 111M on 8 is a
#                         weak-scaling pair.
#
# The figure of merit is s_per_step: the mean wall time of the last 20 time
# steps in timer_stats.csv. The first steps also do setup, mesh processing and
# first-touch page migration, so they're not representative of steady state;
# total_s keeps them.
#
# Settings, all optional:
#   CS_BENCH_CASES   space-separated <case>:<steps>[:<min_ranks>], where
#                    <case> is a tutorial's <study>/<case> or a UEABS_CAVITY_*
#                    one, and runs on fewer than <min_ranks> ranks are skipped
#                    (default: all four cases above; 111M on 8 ranks only)
#   CS_BENCH_RANKS   rank counts to run each case on (default "1 2 4 8"); counts
#                    above the number of visible GPUs are skipped.
#   CS_BENCH_XNACK   1 (default) or 0. AMD only: with XNACK, managed memory
#                    migrates on GPU page faults. Was worth up to ~5x on
#                    05_Mixing_Tee under SCALE.
#
# Writes one CSV row per case and rank count to $RESULTS_DIR. A failed run is
# recorded as such and the rest carry on; the script fails only if no run
# succeeded.
# shellcheck source-path=SCRIPTDIR
. "$(dirname "$0")"/../../util/prelude.sh
. "$(dirname "$0")"/../common.bash

default_cases=(
    05_Mixing_Tee/RANS:100
    12_Tee_Junction/CASE1:600
    UEABS_CAVITY_13M:100
    UEABS_CAVITY_111M:100:8
)
cases="${CS_BENCH_CASES:-${default_cases[*]}}"
rank_counts="${CS_BENCH_RANKS:-1 2 4 8}"
xnack="${CS_BENCH_XNACK:-1}"
compiler="${BENCHMARK_COMPILER:-scale}"

case "${compiler}" in
scale)
    use_openmpi
    export SCALE_AMD_XNACK="${xnack}" HSA_XNACK="${xnack}"
    ;;
nvcc)
    use_openmpi
    xnack=""
    ;;
hip)
    use_openmpi "${PWD}/openmpi-rocm/install"
    export HSA_XNACK="${xnack}"
    # ROCm 7.2's lazy code-object loading deadlocks in the first SpMV launch.
    export HIP_ENABLE_DEFERRED_LOADING=0
    ;;
*)
    log "Unknown BENCHMARK_COMPILER '${compiler}'"
    exit 1
    ;;
esac
use_code_saturne
use_numa_binding

n_gpus="$(visible_gpus | wc -l)"
if [[ "${n_gpus}" -eq 0 ]]; then
    log "No GPUs found"
    exit 1
fi

RESULTS_DIR="${RESULTS_DIR:-${PWD}/results}"
mkdir -p "${RESULTS_DIR}"
csv="${RESULTS_DIR}/code_saturne.${compiler}.${TEST_GPU_ARCH}.$(date '+%Y%m%d-%H%M%S').csv"
echo "case,compiler,arch,xnack,ranks,steps,s_per_step,total_s,status" >"${csv}"

# Prints "<steps>,<s_per_step>,<total_s>" from a run's timer_stats.csv, whose
# second column is each time step's wall time, below two header lines. Fails
# if the run didn't complete a single step.
summarise_timers() {
    awk -F, '
        NR > 2 { step[++n] = $2; total += $2 }
        END {
            if (n == 0) exit 1
            first = (n > 20) ? n - 19 : 1
            for (i = first; i <= n; i++) last += step[i]
            printf "%d,%.4f,%.2f\n", n, last / (n - first + 1), total
        }' "$1"
}

set_steps() {
    sed -i "s#<iterations>[0-9]*</iterations>#<iterations>$2</iterations>#" "$1"
}

# Set up a tutorial case in <run_dir> and print its case directory.
setup_tutorial() {
    local run_dir="$1" case_path="$2" steps="$3"
    local study="${case_path%%/*}"

    cp -r "saturne_tutorials/${study}" "${run_dir}/"
    rm -rf "${run_dir}/${study}"/*/RESU/*
    set_steps "${run_dir}/${case_path}/DATA/setup.xml" "${steps}"
    echo "${run_dir}/${case_path}"
}

# Set up a UEABS cavity case in <run_dir> and print its case directory. The
# 111M case refines the mesh once, which needs a time step 3x smaller to stay
# stable, as in UEABS.
setup_ueabs_cavity() {
    local run_dir="$1" name="$2" steps="$3"
    local case_dir="${run_dir}/UEABS_CAVITY/CAVITY"
    local dt

    case "${name}" in
    UEABS_CAVITY_13M) dt=0.01 ;;
    UEABS_CAVITY_111M) dt=0.003333333333 ;;
    *)
        log "Unknown UEABS case ${name}"
        return 1
        ;;
    esac

    (cd "${run_dir}" && code_saturne create --study UEABS_CAVITY --case CAVITY) >/dev/null
    cp "${SCRIPT_DIR}/ueabs_cavity/setup.xml" "${case_dir}/DATA/setup.xml"
    sed -i \
        -e "s#<mesh_input path=\"[^\"]*\"/>#<mesh_input path=\"${PWD}/ueabs/mesh_input.csm\"/>#" \
        -e "s#<time_step_ref>[^<]*</time_step_ref>#<time_step_ref>${dt}</time_step_ref>#" \
        "${case_dir}/DATA/setup.xml"
    set_steps "${case_dir}/DATA/setup.xml" "${steps}"
    if [[ "${name}" == UEABS_CAVITY_111M ]]; then
        cp "${SCRIPT_DIR}/ueabs_cavity/cs_user_mesh.cpp" "${case_dir}/SRC/"
    fi
    echo "${case_dir}"
}

# One run of a case on a number of ranks, in a fresh copy of its study.
run_case() {
    local name="$1" steps="$2" ranks="$3"
    local run_dir="${PWD}/bench/${name//\//_}.n${ranks}.r${BENCHMARK_REPEAT:-1}"
    local case_dir row

    rm -rf "${run_dir}"
    mkdir -p "${run_dir}"
    if [[ "${name}" == UEABS_CAVITY_* ]]; then
        case_dir="$(setup_ueabs_cavity "${run_dir}" "${name}" "${steps}")"
    else
        case_dir="$(setup_tutorial "${run_dir}" "${name}" "${steps}")"
    fi

    log "=== ${name}: ${steps} steps on ${ranks} rank(s)"
    if (cd "${case_dir}/DATA" &&
        code_saturne run -n "${ranks}" --id run --tool-args "${SCRIPT_DIR}/gpubind" \
            </dev/null >"${run_dir}/run.log" 2>&1) &&
        row="$(summarise_timers "${case_dir}/RESU/run/timer_stats.csv")"; then
        log "${row}"
        echo "${name},${compiler},${TEST_GPU_ARCH},${xnack},${ranks},${row},ok" >>"${csv}"
    else
        tail -20 "${run_dir}/run.log" >&2
        echo "${name},${compiler},${TEST_GPU_ARCH},${xnack},${ranks},,,,fail" >>"${csv}"
    fi
}

for spec in ${cases}; do
    IFS=: read -r name steps min_ranks <<<"${spec}"
    for ranks in ${rank_counts}; do
        if [[ "${ranks}" -gt "${n_gpus}" ]]; then
            log "Skipping ${name} on ${ranks} ranks: only ${n_gpus} GPU(s)"
        elif [[ "${ranks}" -lt "${min_ranks:-1}" ]]; then
            log "Skipping ${name} on ${ranks} ranks: it needs at least ${min_ranks}"
        else
            run_case "${name}" "${steps}" "${ranks}"
        fi
    done
done

column -s, -t "${csv}" >&2 || cat "${csv}" >&2

if ! grep -q ',ok$' "${csv}"; then
    log "No run succeeded"
    exit 1
fi
