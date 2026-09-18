#!/usr/bin/env bash
. "$(dirname "$0")"/../../util/prelude.sh
. "$SCRIPT_DIR/vars-nvidia"
. "$SCRIPT_DIR/../tools/madness.sh"
ExtendedOpenDwarfs/runner.sh --no-plots
