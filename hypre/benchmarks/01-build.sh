#!/usr/bin/env bash
# shellcheck source-path=SCRIPTDIR
. "$(dirname "$0")"/../../util/prelude.sh

# Benchmark without unified memory, as upstream does, on every toolchain. On
# AMD GPUs without XNACK, managed memory would also be much slower.
HYPRE_UNIFIED_MEMORY=0 "$SCRIPT_DIR/../01-build.sh"
