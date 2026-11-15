#!/usr/bin/env bash
# shellcheck source-path=SCRIPTDIR
. "$(dirname "$0")"/../../util/prelude.sh

# The base 01-patch.sh works around SCALE gaps. Native HIP builds stock upstream.
log "HIP: building stock upstream llama.cpp, no patches"
