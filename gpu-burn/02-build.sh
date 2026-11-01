#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh

make -C gpu-burn CUDAPATH="${CUDA_PATH}" COMPUTE="${CUDAARCHS}"
