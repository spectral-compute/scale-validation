#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh

# Same build as the pytorch project.
"${SCALE_VALIDATION}/pytorch/02-build-pytorch.sh"
