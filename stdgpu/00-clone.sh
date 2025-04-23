#!/bin/bash

set -e
source "$(dirname "$0")"/../util/args.sh "$@"

mkdir -p "${OUT_DIR}/stdgpu"
cd "${OUT_DIR}/stdgpu"

do_clone_hash stdgpu https://github.com/stotko/stdgpu.git 563dc59d6d08dfaa0adbbcbd8dc079c1a78a2a79
