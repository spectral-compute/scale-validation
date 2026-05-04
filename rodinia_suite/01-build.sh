#!/bin/bash

set -ETeuo pipefail

./rodinia_suite/cuda/buildall.sh --cuda ${CUDA_PATH} --sm ${CUDAARCHS} --spectral
