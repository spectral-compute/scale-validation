#!/usr/bin/env bash
# shellcheck source-path=SCRIPTDIR
. "$(dirname "$0")"/../../util/prelude.sh

# The full MPI benchmark suite takes about an hour per toolchain. Opt in.
if [[ "${GROMACS_BENCH_LONG:-0}" != 1 ]]; then
    log "Skipping the long suite; set GROMACS_BENCH_LONG=1 to run it"
    exit 0
fi
exec bash "$(dirname "$0")/../05-bench-long.sh"
