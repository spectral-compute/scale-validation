#!/bin/bash

set -ETeuo pipefail

./rodinia_suite/cuda/buildall.sh ${CUDA_PATH} ${CUDAARCHS} true
