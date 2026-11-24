#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh

# The Makefile hardcodes NVCC as ${CUDAPATH}/bin/nvcc. On NVIDIA targets, scaleenv's
# CUDA_PATH is NVIDIA's toolkit, so use whichever nvcc is first in PATH instead.
args=(CUDAPATH="${CUDA_PATH}" NVCC="$(command -v nvcc)")

if [[ -n "${SCALE_ENV:-}" && "${TEST_GPU_ARCH}" == sm_* ]]; then
    # SCALE's nvcc bug: `-arch=compute_NN -fatbin` runs ptxas on the virtual arch,
    # which exits 0 without writing anything, instead of embedding the PTX. Build
    # SASS for the real arch instead (an empty COMPUTE drops the Makefile's -arch).
    args+=(COMPUTE= NVCCFLAGS="-arch=sm_${CUDAARCHS}")
else
    args+=(COMPUTE="${CUDAARCHS}")
fi

make -C gpu-burn "${args[@]}"
