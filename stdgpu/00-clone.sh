#!/bin/bash

set -e
source "$(dirname "$0")"/../util/args.sh "$@"

mkdir -p "${OUT_DIR}/stdgpu"
cd "${OUT_DIR}/stdgpu"

do_clone_hash stdgpu https://github.com/stotko/stdgpu.git 1.3.0
