#!/bin/bash

set -e
SCRIPT_DIR="$(realpath "$(dirname "$0")")"
source "${SCRIPT_DIR}"/../util/args.sh "$@"

export PATH="${CUDA_PATH}/bin:${PATH}"

cd "${OUT_DIR}/risc0/risc0"

cargo install --force --path risc0/cargo-risczero
cargo risczero install
cargo risczero init
rzup install
