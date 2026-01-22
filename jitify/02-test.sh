#!/bin/bash

set -ETeuo pipefail

# TODO: https://gitlab.com/spectral-ai/engineering/cuda/platform/redscale/-/issues/549
./jitify/jitify_test --gtest_filter="-JitifyTest.ConstantMemory:JitifyTest.ConstantMemory_experimental:JitifyTest.RemoveUnusedGlobals:JitifyTest.LinkExternalFiles:JitifyTest.LinkCurrentExecutable"
