#!/bin/bash

set -ETeuo pipefail

./rodinia_suite/cuda/buildall.sh ${CUDA_PATH} ${SCALE_FAKE_CUDA_ARCH} true
