#!/bin/bash

set -ETeuo pipefail
SCRIPT_DIR="$(realpath "$(dirname "$0")")"
source "${SCRIPT_DIR}"/../util/args.sh "$@"

cd ${OUT_DIR}/rodinia_suite/rodinia_suite/cuda

CUDA_ARCHITECTURES="$(echo "${GPU_ARCH}" | sed -E 's/sm_//g')"
./buildall.sh ${CUDA_PATH} ${CUDA_ARCHITECTURES} true


