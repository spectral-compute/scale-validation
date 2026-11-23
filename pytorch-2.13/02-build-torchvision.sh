#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh

# The pytorch project's torchvision build, with the release that pairs with PyTorch 2.13.
"${SCALE_VALIDATION}/pytorch/03-build-torchvision.sh" torchvision-2.13
