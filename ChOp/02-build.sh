#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh
. "$(dirname "$0")"/chapel.env
PATH="${CHPL_HOME}/bin/$("${CHPL_HOME}"/util/chplenv/chpl_bin_subdir.py):${PATH}"

# ChOp's Makefile runs $(CUDA_PATH)/bin/nvcc, which on NVIDIA targets is NVIDIA's nvcc, not SCALE's. Use the nvcc on
# PATH, as the standalone builds below do. CUDA_PATH itself must stay as it is: SCALE uses it to find the CUDA install.
# shellcheck disable=SC2016
sed -i 's|$(CUDA_PATH)/bin/nvcc|nvcc|' ChOp/Makefile

# Chapel single-locale search with the CUDA kernels in libs/libqueens.so.
make -C ChOp CUDA_HOME="${CUDA_PATH}" queens_singlelocale_cuda

# The standalone CUDA versions, built as NQueens/cudaOnly/compiling says.
cd ChOp/NQueens/cudaOnly
nvcc -arch="sm_${CUDAARCHS}" -O3 -DIMPROVED -DCHECKSOLS singleGPUQueens.cu -o singleGPUQueens
nvcc -arch="sm_${CUDAARCHS}" -Xcompiler -fopenmp -O3 -DIMPROVED -DCHECKSOLS multiGPUQueens.cu -o multiGPUQueens
