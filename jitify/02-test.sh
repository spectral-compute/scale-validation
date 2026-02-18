#!/bin/bash

set -ETeuo pipefail

cd jitify
# TODO: https://gitlab.com/spectral-ai/engineering/cuda/platform/redscale/-/issues/549
./jitify_test --gtest_filter="-JitifyTest.ConstantMemory:JitifyTest.ConstantMemory_experimental:JitifyTest.RemoveUnusedGlobals:JitifyTest.LinkExternalFiles:JitifyTest.LinkCurrentExecutable"
