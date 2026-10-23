#!/usr/bin/env bash
# shellcheck source-path=SCRIPTDIR
. "$(dirname "$0")"/../../util/prelude.sh

"$SCRIPT_DIR/../01-patch.sh"

# hipew.patch: Cycles loads the HIP runtime itself and tries libamdhip64.so.5
# first, so with ROCm 6+ it can pick up a stray distro ROCm 5 runtime (e.g.
# Ubuntu's libamdhip64-5) and crash in hipInit. Prefer newer runtimes.
patch -p0 -d "cycles" <"${SCRIPT_DIR}/hipew.patch"
