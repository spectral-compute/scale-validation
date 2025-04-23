#!/bin/bash

set -ETeuo pipefail
SCRIPT_DIR="$(realpath "$(dirname "$0")")"
source "${SCRIPT_DIR}"/../util/args.sh "$@"

export PATH="${CUDA_PATH}/bin:${PATH}"
export CUDACXX="${CUDA_PATH}/bin/nvcc"

cd "${OUT_DIR}/cudf/cudf"
./build.sh