#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh

# The pytorch project's torchvision build, with the newest release (there is none for 2.15 yet).
"${SCALE_VALIDATION}/pytorch/03-build-torchvision.sh" torchvision-2.15
