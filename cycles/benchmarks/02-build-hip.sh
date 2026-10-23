#!/usr/bin/env bash
# shellcheck source-path=SCRIPTDIR
. "$(dirname "$0")"/../../util/prelude.sh

# Native ROCm build, using Cycles's own HIP backend, as a baseline for SCALE.
CYCLES_DEVICE=HIP "$SCRIPT_DIR/../02-build.sh"
