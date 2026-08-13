#!/bin/bash

set -ETeuo pipefail

cd jitify

# TODO: https://code.spectralcompute.com/spectral-compute/scale/issues/1116
if [[ ! $SCALE_ENV == gfx* ]]; then
	FAILS_FOR_NV="JitifyTest.ClassKernelArg"
fi

# TODO: https://gitlab.com/spectral-ai/engineering/cuda/platform/redscale/-/issues/549
./jitify_test --gtest_filter="-JitifyTest.ConstantMemory:JitifyTest.ConstantMemory_experimental:JitifyTest.RemoveUnusedGlobals:JitifyTest.LinkExternalFiles:JitifyTest.LinkCurrentExecutable:${FAILS_FOR_NV:-}"
