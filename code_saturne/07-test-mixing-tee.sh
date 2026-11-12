#!/usr/bin/env bash
# shellcheck disable=2329
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

. "$(dirname "$0")"/../util/prelude.sh
. "$(dirname "$0")"/common.bash
. "$(dirname "$0")"/../util/checks.sh

use_code_saturne
use_openmpi
use_numa_binding
use_device_uvm_workaround

repo="$(realpath saturne_tutorials)"

dest="${CS_SMGR_DEST:-$(realpath .)/saturne_tutorials_run}"
mkdir -p "${dest}"

# The RANS case's setup.xml asks for 3000 iterations; set this to cut a smoke
# test short.
smgr_args=()
if [[ -n "${CS_SMGR_ITERATIONS:-}" ]]; then
    smgr_args+=(-n "${CS_SMGR_ITERATIONS}")
fi

n_procs="${CS_SMGR_N_PROCS:-4}"

smgr_log="${dest}/smgr_output.log"
smgr_status=0
code_saturne smgr -f "${repo}/05_Mixing_Tee/smgr.xml" \
    --repo="${repo}" --dest="${dest}" \
    --n-procs="${n_procs}" \
    "${smgr_args[@]}" \
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

check "studymanager exited cleanly" check_smgr_exit
check "every case ran (none skipped or cancelled)" check_cases_ran
check "every case completed" check_cases_succeeded

check_exit
