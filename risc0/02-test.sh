#!/bin/bash

set -e
SCRIPT_DIR="$(realpath "$(dirname "$0")")"
source "${SCRIPT_DIR}"/../util/args.sh "$@"

export PATH="${CUDA_PATH}/bin:${PATH}"
export NVCC="${CUDA_PATH}/bin/nvcc"
export RUST_BACKTRACE=1

cd "${OUT_DIR}/risc0/risc0"

RUSTFLAGS="-C target-cpu=native" cargo run --verbose -F cuda -r --example datasheet
