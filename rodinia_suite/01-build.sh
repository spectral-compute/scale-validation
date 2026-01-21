#!/bin/bash

set -ETeuo pipefail

CUDA_ARCHITECTURES="${SCALE_FAKE_CUDA_ARCH}"
./rodinia_suite/cuda/buildall.sh ${CUDA_PATH} ${CUDA_ARCHITECTURES} true
