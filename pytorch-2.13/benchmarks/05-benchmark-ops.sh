#!/usr/bin/env bash
# shellcheck source-path=SCRIPTDIR
. "$(dirname "$0")"/../../util/prelude.sh

source pytorch/.venv/bin/activate
python "${SCRIPT_DIR}/bench.py"
