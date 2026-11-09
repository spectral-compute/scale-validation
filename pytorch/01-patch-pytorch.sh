#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh

OUT_DIR=$(realpath .)

# 1) Add -k to pytorch build
cd "${OUT_DIR}/pytorch/tools/setup_helpers"
git stash

# Make Ninja quiet so there is no build log spam
git apply "${SCRIPT_DIR}/patches/0001-quiet-ninja.patch"

# 2) Patch CUTLASS sources
source "${SCRIPT_DIR}/util/cutlass-patches.sh"
patch_pytorch_cutlass "${OUT_DIR}/pytorch/third_party/cutlass"
