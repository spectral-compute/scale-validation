#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh

source "${SCALE_VALIDATION}/pytorch/util/cutlass-patches.sh"
patch_pytorch_cutlass pytorch/third_party/cutlass

# sgl-kernel hardcodes gencodes from sm_80 up to sm_121a. SCALE maps every
# compute capability to the one target GPU, so these would build the Hopper and
# Blackwell code paths for it. Drop them: CMake then builds for ${CUDAARCHS},
# which it reads from the environment.
cd sglang/python/sglang/kernels/aot
sed -Ee 's|"-gencode=arch=compute_[0-9]+[af]?,code=sm_[0-9]+[af]?"||' \
    -i CMakeLists.txt cmake/flashmla.cmake
! grep -q -- '-gencode=' CMakeLists.txt cmake/flashmla.cmake
