#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(realpath "$(dirname "$0")")"
source "${SCRIPT_DIR}"/../util/args.sh "$@"

cd "${OUT_DIR}/tiny-cuda-nn/"
pwd
./build/mlp_learning_an_image tiny-cuda-nn/data/images/albert.jpg 10000
