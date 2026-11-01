#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh

# FAISS: just the C++ library with its GPU indices.
cmake -B faiss-build -S faiss \
    -DFAISS_ENABLE_GPU=ON \
    -DFAISS_ENABLE_PYTHON=OFF \
    -DBUILD_TESTING=OFF \
    -DBUILD_SHARED_LIBS=ON \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_CUDA_COMPILER=nvcc \
    -DCMAKE_CUDA_ARCHITECTURES="${CUDAARCHS}" \
    -DCMAKE_INSTALL_PREFIX="${PWD}/faiss-install"
cmake --build faiss-build --target install -j"$(nproc)"

# tsne-cuda: libtsnecuda.so plus the Python package around it, in build/python.
cmake -B build -S tsne-cuda \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_CUDA_COMPILER=nvcc \
    -DCMAKE_CUDA_ARCHITECTURES="${CUDAARCHS}" \
    -DCMAKE_PREFIX_PATH="${PWD}/faiss-install"
cmake --build build -j"$(nproc)"
