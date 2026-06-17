#!/bin/bash

set -ETeuo pipefail

SCRIPT_DIR="$(realpath "$(dirname "$0")")"

cd cuml

# Configure the cuvs-free, single-GPU algorithm subset.
#  - cuvs (CAGRA/IVF/distance) compiles its kernels through a JIT-LTO pipeline
#    (nvcc -fatbin + nvJitLink) that SCALE 1.7.1 does not implement, so the 7
#    cuvs-linked algorithms (dbscan/hdbscan/kmeans/knn/metrics/tsne/umap) are
#    excluded. The remaining subset is linear_model, decomposition, ensemble,
#    tsa and solvers.
#  - --singlegpu turns off the multi-GPU comms that would otherwise require
#    NCCL/RCCL (which SCALE does not ship).
#  - --configure-only so we can patch a fetched dependency before building.
export CUML_EXTRA_CMAKE_ARGS="-DCMAKE_CUDA_ARCHITECTURES=${CUDAARCHS} -DCUML_ALGORITHMS=linear_model;decomposition;ensemble;tsa;solvers"
./build.sh libcuml --singlegpu --nolibcumltest --configure-only

# Patch raft (fetched by rapids-cmake/CPM into the build tree) for SCALE's
# const-correctness difference in cublas{S,D}getriBatched: SCALE declares the
# pivot array as `int* PivotArray`, NVIDIA's API (and raft) use `const int*`.
# Wrap the pivot pointer in const_cast<int*> to match SCALE's declaration.
RAFT_CUBLAS="cpp/build/_deps/raft-src/cpp/include/raft/linalg/detail/cublas_wrappers.hpp"
sed -i -E 's/(cublas[SD]getriBatched\(handle, n, A, lda, )P(, C, ldc, info, batchSize\))/\1const_cast<int*>(P)\2/' \
    "${RAFT_CUBLAS}"

# Build with the SCALE compatibility flags appended (NVCC_APPEND_FLAGS is applied
# last by SCALE, so it overrides the project's -Werror=all-warnings):
#  -Xcompiler=-Wno-error          : SCALE's clang is stricter than nvcc; benign
#                                    warnings would otherwise be fatal.
#  -DCCCL_DISABLE_WARPSPEED_SCAN  : CUB's warpspeed scan hits a SCALE AMD-backend
#                                    codegen error (illegal VGPR to SGPR copy).
#  -include scale_cusolver_shim.h : supply cusolver symbols SCALE omits.
export NVCC_APPEND_FLAGS="-Xcompiler=-Wno-error -DCCCL_DISABLE_WARPSPEED_SCAN -include ${SCRIPT_DIR}/scale_cusolver_shim.h ${NVCC_APPEND_FLAGS:-}"
ninja -C cpp/build -k0 -j"$(nproc)"
