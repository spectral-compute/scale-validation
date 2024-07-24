#!/bin/bash

set -e
source "$(dirname "$0")"/../util/args.sh "$@"

mkdir -p "${OUT_DIR}/stdgpu"
cd "${OUT_DIR}/stdgpu"
git clone https://github.com/stotko/stdgpu.git
