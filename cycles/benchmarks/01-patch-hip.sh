#!/usr/bin/env bash
# shellcheck source-path=SCRIPTDIR
. "$(dirname "$0")"/../../util/prelude.sh

"$SCRIPT_DIR/../01-patch.sh"

# hipew.patch: Cycles loads the HIP runtime itself, trying libamdhip64.so.5
# first, so it can pick up a stray distro ROCm 5 runtime (e.g. Ubuntu's
# libamdhip64-5) that doesn't match the toolkit, and crash in hipInit. When
# $ROCM_PATH is set (benchmark.py sets it), load that install's runtime first;
# otherwise the upstream search is unchanged.
patch -p0 -d "cycles" <"${SCRIPT_DIR}/hipew.patch"
