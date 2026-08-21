#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh

./rodinia_suite/cuda/buildall.sh --cuda "${CUDA_PATH}" --sm "${CUDAARCHS}" --spectral
