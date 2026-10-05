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

# SCALE only (scaleenv sets SCALE_ENV): never apply these to NVIDIA's nvcc.
if [[ -n "${SCALE_ENV:-}" ]]; then
    # This also serves to conveniently explode if we accidentially end up using nvidia nvcc.
    export NVCC_PREPEND_FLAGS="-fdiagnostics-color=always"
    export CXXFLAGS="-fdiagnostics-color=always"
    export CFLAGS="-fdiagnostics-color=always"
    export CMAKE_COLOR_DIAGNOSTICS=ON

    # A buildsystem-independent way of avoiding warning spam.
    # These warnings matter, but nvidia ignores them and the torrent makes CI runs
    # overflow the output limit.
    export NVCC_APPEND_FLAGS="-Wno-deprecated-literal-operator -Wno-format -Wno-unknown-warning-option -Wno-ignored-qualifiers -Wno-cuda-wrong-side -Wno-unused-function -Wno-unused-local-typedef -Wno-unused-parameter -Wno-int-conversion -Wno-sign-conversion -Wno-shorten-64-to-32 -Wno-template-id-cdtor -Wno-switch -Wno-vla-cxx-extension -Wno-missing-template-arg-list-after-template-kw -Wno-deprecated-declarations -Wno-c++11-narrowing-const-reference -Wno-typename-missing -Wno-unknown-pragmas -Wno-inconsistent-missing-override -Wno-unused-private-field -Wno-sign-compare -Wno-pessimizing-move -Wno-unused-result -Wno-invalid-constexpr -Wno-unused-but-set-variable -Wno-unused-variable -Wno-unused-value -Wno-implicit-const-int-float-conversion -Wno-pass-failed"
fi

# Other helper functions
source "$SCALE_VALIDATION/util/git.sh"

# Print some informational output to stderr
function log() {
    echo >&2 -e "$@"
}
