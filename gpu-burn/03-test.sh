#!/usr/bin/env bash
# shellcheck disable=2329
. "$(dirname "$0")"/../util/prelude.sh

source "$SCALE_VALIDATION/util/checks.sh"

# gpu_burn loads compare.fatbin from the working directory.
cd gpu-burn

# gpu_burn exits 0 even when it finds errors, so check its report instead: every GPU tested must
# be reported OK and have completed some GEMMs (a child that never reports is also "OK").
_burn() {
    local out
    out="$(./gpu_burn "$@" | tr '\r' '\n')" || return 1
    echo "${out}"
    local tested ok progress
    tested="$(echo "${out}" | sed -nE 's/^Tested ([0-9]+) GPUs:$/\1/p')"
    ok="$(echo "${out}" | grep -cE '^\s+GPU [0-9]+: OK$')"
    progress="$(echo "${out}" | grep -E "proc'd: " | tail -n 1)"
    echo "tested=${tested} ok=${ok} last progress: ${progress}"
    [ -n "${tested}" ] && [ "${tested}" -gt 0 ] && [ "${ok}" -eq "${tested}" ] &&
        ! echo "${progress}" | grep -qE "proc'd: 0 |-1 |DIED|WARNING" &&
        [ -n "${progress}" ]
}

check_list() {
    ./gpu_burn -l | grep -E '^ID 0: '
}

check_floats() { _burn -m 2048 20; }
check_doubles() { _burn -d -m 2048 20; }
check_tensor_cores() { _burn -tc -m 2048 20; }
check_single_gpu() { _burn -i 0 -m 50% 20; }

check "list GPUs" check_list
check "SGEMM burn" check_floats
check "DGEMM burn" check_doubles
check "SGEMM burn, tensor-op math" check_tensor_cores
check "burn GPU 0 only, half its memory" check_single_gpu

check_exit
