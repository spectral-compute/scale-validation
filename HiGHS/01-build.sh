#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh

# CUPDLP_GPU builds the cuPDLP-C and HiPDLP first-order LP solvers for the GPU (cuBLAS, cuSPARSE).
cmake -B build -S HiGHS \
    -DCUPDLP_GPU=ON \
    -DALL_TESTS=ON \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_CUDA_COMPILER=nvcc \
    -GNinja

# -k 0: build as much as possible, for more signal on what's unsupported.
ninja -C build -k 0
