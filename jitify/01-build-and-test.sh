#!/bin/bash

set -ETeuo pipefail

SCRIPT_DIR="$(realpath "$(dirname "$0")")"
source "${SCRIPT_DIR}"/../util/args.sh "$@"

cd "${OUT_DIR}/jitify/jitify"
make jitify_test
# TODO: https://gitlab.com/spectral-ai/engineering/cuda/platform/redscale/-/issues/549
./jitify_test --gtest_filter="-JitifyTest.ConstantMemory:JitifyTest.ConstantMemory_experimental:JitifyTest.RemoveUnusedGlobals:JitifyTest.LinkExternalFiles:JitifyTest.LinkCurrentExecutable"
