#!/usr/bin/env bash
# Do setup that most scripts should do. Sets some bash flags.
# If SPECTRAL_TRACE=1, log every command executed
set -ETeuo pipefail
if [[ "${SPECTRAL_TRACE:-}" == "1" ]]; then
    set -x
fi

SCALE_VALIDATION="$(dirname "${BASH_SOURCE[0]}")/.." # When this is sourced, BASH_SOURCE[0] is what you'd expect $0 to be
SCRIPT_DIR="$(realpath "$(dirname "$0")")"           # and $0 is the top-level: the thing sourcing this script
export SCALE_VALIDATION
export SCRIPT_DIR

# Other helper functions
source "$SCALE_VALIDATION/util/git.sh"

# Print some informational output to stderr
function log() {
    >&2 echo -e "$@"
}

# A recent change to `test.sh` allowed passing the ROCm install
# path as an argument. As this requires a different compiler chain
# and set of build flags and environment variables, we define this
# helper function to go on every test that doesn't yet support being
# built with ROCm to avoid it raising spurious errors during the
# compilation process.
function raise_error_if_using_rocm() {
	if [[ "${TEST_MODE:-}" == "hip-amd" ]]; then
		log "This test does not currently support being build with ROCm/HIP."
		log "Once support has been added, remove this function from that test's scripts."
		exit 1
	fi
}
