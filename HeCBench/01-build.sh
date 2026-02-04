#!/usr/bin/env bash

cmake HeCBench \
    -DCMAKE_CUDA_COMPILER=nvcc \
    -DCMAKE_CUDA_ARCHITECTURES=$CUDAARCHS \
    --preset=cuda-sm80 \
    && ninja -C HeCBench/build/cuda-sm80 -k 0
