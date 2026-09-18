#!/usr/bin/env bash
. "$(dirname "$0")"/../../util/prelude.sh

"$SCRIPT_DIR/../00-clone.sh"
"$SCRIPT_DIR/../01-install-deps.sh"

# Fail early if some variables are missing
export APP="${APP:?Missing APP}"
export BACKEND="${BACKEND:?Missing BACKEND}"
export COMPILER="${COMPILER:?Missing COMPILER}"

ExtendedOpenDwarfs/runner.sh --no-plots
