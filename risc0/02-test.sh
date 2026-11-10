#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh

export PATH="${CUDA_PATH}/bin:${PATH}"
export NVCC="${CUDA_PATH}/bin/nvcc"
# On Linux, cust's find_cuda_helper looks for <dir>/lib64 only under these (and /usr/local/cuda*).
export CUDA_LIBRARY_PATH="${CUDA_PATH}"
export RUST_BACKTRACE=1

(
    cd risc0 &&
        RUSTFLAGS="-C target-cpu=native" cargo run --verbose -F cuda -r --example datasheet

)
