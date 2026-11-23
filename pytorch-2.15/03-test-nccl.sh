#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh

# The pytorch-2.13 project's NCCL checks.
"${SCALE_VALIDATION}/pytorch-2.13/03-test-nccl.sh"
