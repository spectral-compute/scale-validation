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
