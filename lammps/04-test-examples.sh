#!/bin/bash
set -e

source "$(dirname "$0")"/../util/checks.sh

LMP="./build/lmp"

# final_thermo <log> <column>
# LAMMPS prints a thermo table per run (col headers: Step Temp E_pair E_mol TotEng Press)
# one row per output step, ending with"Loop time of ..."
# Returns the named column of the last row of the LAST such table in the file (in.min has two: an MD run, then a minimisation).
final_thermo() {
    local log="$1" want="$2"
    awk -v want="${want}" '
        $1 == "Step" { delete col; for (i = 1; i <= NF; i++) col[$i] = i; nc = NF; next }
        nc > 0 && NF == nc && $1 ~ /^-?[0-9]/ { for (i = 1; i <= NF; i++) row[i] = $i; next }
        /^Loop time of/ { if (want in col) last = row[col[want]]; nc = 0; next }
        END { if (last == "") exit 1; print last }
    ' "${log}"
}

# approx_eq <actual> <expected> <tolerance>
# returns nonzero if the difference exceeds the tolerance
approx_eq() {
    awk -v a="$1" -v e="$2" -v t="$3" 'BEGIN {
        d = a - e; if (d < 0) d = -d
        printf "  actual=%s expected=%s delta=%.6g tolerance=%s\n", a, e, d, t
        exit (d <= t) ? 0 : 1
    }'
}

# Note: Molecular dynamics is chaotic, and Temp and E_pair at a given step diverge between CPU and
# GPU from summation order alone. But a conserved or converged quantity is stable, so checking that.

# 3d Lennard-Jones melt, 4000 atoms, 250 steps of NVE
check_melt() {
    "${LMP}" -sf gpu -pk gpu 1 -in lammps/examples/melt/in.melt -log melt.log \
        > melt.screen.log 2>&1 || return 1
    local toteng
    toteng="$(final_thermo melt.log TotEng)" || return 1
    approx_eq "${toteng}" -2.2812174 0.01
}

# 2d Lennard-Jones melt followed by an energy minimisation, 800 atoms.
#
# Included for future reminder that it isn't a bug, and GPU vs CPU calcs do actually differ here.
# in.min chains 1000 steps of chaotic NVE dynamics into the minimiser, so GPU summation
# order lands it in an actually different local energy basin than CPU. Not a bug.
# But may be handy for tests in futture.
check_min() {
    "${LMP}" -sf gpu -pk gpu 1 -in lammps/examples/min/in.min -log min.log \
        || return 1
    local epair
    epair="$(final_thermo min.log E_pair)" || return 1
    approx_eq "${epair}" -2.9169436 0.2
}

# LAMMPS silently falls back to the plain CPU style for any style with no /gpu variant :(
check_gpu_suffix_in_use() {
    grep -F 'Using acceleration for lj/cut:' melt.screen.log
}

check "melt: final TotEng matches reference" check_melt
check "min: converged E_pair matches reference" check_min
check "melt ran the lj/cut/gpu style, not a CPU fallback" check_gpu_suffix_in_use

check_exit
