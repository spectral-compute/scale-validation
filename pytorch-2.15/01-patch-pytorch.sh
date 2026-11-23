#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh

# The pytorch-2.13 project's patches: 2.15 needs nothing more.
"${SCALE_VALIDATION}/pytorch-2.13/01-patch-pytorch.sh"
