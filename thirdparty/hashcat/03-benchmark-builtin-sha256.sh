#!/bin/bash

set -e
SCRIPT_DIR="$(realpath "$(dirname "$0")")"
source "${SCRIPT_DIR}"/../util/args.sh "$@"
export LD_LIBRARY_PATH="${CUDA_DIR}/lib"
cd "${OUT_DIR}/hashcat"

mkdir -p out
rm -f out/benchmark-builtin-sha256.log

build/hashcat --backend-ignore-hip --backend-ignore-opencl -m 1400 -b | tee out/benchmark-builtin-sha256.log
