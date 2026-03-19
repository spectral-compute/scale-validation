#!/usr/bin/env bash

cmake HeCBench \
    -DCMAKE_CUDA_COMPILER=nvcc \
    -DCMAKE_CUDA_ARCHITECTURES=$CUDAARCHS \
    --preset=cuda-sm${CUDAARCHS}

# continue to run script even if there are compile errrors
ninja -C HeCBench/build/cuda-sm${CUDAARCHS} -k 0 || true
