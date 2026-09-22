#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh
raise_error_if_using_rocm

./rodinia_suite/cuda/buildall.sh --cuda "${CUDA_PATH}" --sm "${CUDAARCHS}" --spectral
