#!/bin/bash

set -e
source "$(dirname "$0")"/../util/args.sh "$@"
cd "${OUT_DIR}/stdgpu"

build/bin/teststdgpu --gtest_output=xml:stdgpu.xml
