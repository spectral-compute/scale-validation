#!/bin/bash
set -e

source "$(dirname "$0")"/../util/checks.sh

# Runs a couple of the examples LAMMPS ships and checks the answers against the reference
# log files that ship beside them. see other LAMMPS folder for details on the tests below.



LMP="./build/lmp"
KK_ARGS=(-k on g 1 -sf kk -pk kokkos newton on neigh half)

final_thermo() {
    local log="$1" want="$2"
    awk -v want="${want}" '
        $1 == "Step" { delete col; for (i = 1; i <= NF; i++) col[$i] = i; nc = NF; next }
        nc > 0 && NF == nc && $1 ~ /^-?[0-9]/ { for (i = 1; i <= NF; i++) row[i] = $i; next }
        /^Loop time of/ { if (want in col) last = row[col[want]]; nc = 0; next }
        END { if (last == "") exit 1; print last }
    ' "${log}"
}

approx_eq() {
    awk -v a="$1" -v e="$2" -v t="$3" 'BEGIN {
        d = a - e; if (d < 0) d = -d
        printf "  actual=%s expected=%s delta=%.6g tolerance=%s\n", a, e, d, t
        exit (d <= t) ? 0 : 1
    }'
}


check_melt() {
    "${LMP}" "${KK_ARGS[@]}" -in lammps-kokkos/examples/melt/in.melt -log melt.log \
        || return 1
    local toteng
    toteng="$(final_thermo melt.log TotEng)" || return 1
    approx_eq "${toteng}" -2.2812174 0.01
}


# Same basin-selection issue as the LAMMPS GPU-package check_min
# But KOKKOS apparently adds extra wobble on top: CUDA + "neigh half" always uses atomic
# operations for force/energy accumulation (LAMMPS's own doc/src/Speed_kokkos.rst)
# so reruns of the same binary/input aren't even bit-identical.
check_min() {
    "${LMP}" "${KK_ARGS[@]}" -in lammps-kokkos/examples/min/in.min -log min.log \
        || return 1
    local epair
    epair="$(final_thermo min.log E_pair)" || return 1
    approx_eq "${epair}" -2.9169436 0.2
}

check_kk_suffix_in_use() {
    grep -F 'lj/cut/kk' melt.log
}

check "melt: final TotEng matches reference" check_melt
check "min: converged E_pair matches reference" check_min
check "melt ran the lj/cut/kk style, not a CPU fallback" check_kk_suffix_in_use

check_exit
