#!/bin/bash

set -e

# Resolve script directory and load common args (defines OUT_DIR, etc.)
SCRIPT_DIR="$(realpath "$(dirname "$0")")"
source "${SCRIPT_DIR}/../util/args.sh" "$@"

# 1) Add -k to pytorch build
echo "Patch Ninja"
cd "${OUT_DIR}/pytorch/pytorch/tools/setup_helpers"
git stash
# Make Ninja quiet so there is no build log spam
git apply "${SCRIPT_DIR}/patches/0001-quiet-ninja.patch"

# 2) Patch CUTLASS sources
echo "Patch CUTLASS"
cd "${OUT_DIR}/pytorch/pytorch/third_party/cutlass/"

# Cutlass disables wmma with clang due to an old clang bug that doesn't apply to SCALE.
sed -Ee 's|#if !\(defined\(__clang__\) && defined\(__CUDA__\)\)|#if 1|' \
  -i "include/cutlass/arch/wmma.h"
sed -Ee 's|#if !\(defined\(__clang__\) && defined\(__CUDA__\)\)|#if 1|' \
  -i "include/cutlass/epilogue/warp/fragment_iterator_wmma_tensor_op.h"
sed -Ee 's|#if !\(defined\(__clang__\) && defined\(__CUDA__\)\)|#if 1|' \
  -i "include/cutlass/epilogue/warp/tile_iterator_wmma_tensor_op.h"
# Always disable clustering.
sed -Ee 's|#  define CUTLASS_SM90_CLUSTER_LAUNCH_ENABLED|//CUTLASS_SM90_CLUSTER_LAUNCH_ENABLED|' \
  -i "include/cutlass/cluster_launch.hpp"
# Disable sparse mma, because we haven't implemented it yet.
sed -Ee 's|#define CUTLASS_ARCH_SPARSE_MMA_SM80_ENABLED|//CUTLASS_ARCH_SPARSE_MMA_SM80_ENABLED|' \
  -i "include/cutlass/arch/mma_sparse_sm80.h"
# Disable tensormaps, because we haven't implemented them yet.
sed -Ee 's|#define CUDA_HOST_ADAPTER_TENSORMAP_ENABLED|//CUDA_HOST_ADAPTER_TENSORMAP_ENABLED|' \
  -i "include/cutlass/cuda_host_adapter.hpp"
sed -Ee 's|#define CUTLASS_ARCH_MMA_MODIFIABLE_TMA_SM90_SUPPORTED|//#define CUTLASS_ARCH_MMA_MODIFIABLE_TMA_SM90_SUPPORTED|' \
  -i "include/cutlass/arch/config.h"
sed -Ee 's|#define CUTLASS_ARCH_MMA_MODIFIABLE_TMA_SM90_ENABLED|//#define CUTLASS_ARCH_MMA_MODIFIABLE_TMA_SM90_ENABLED|' \
  -i "include/cutlass/arch/config.h"
sed -Ee 's|#define CUTLASS_ARCH_MMA_MODIFIABLE_TMA_SM90A_ENABLED|//#define CUTLASS_ARCH_MMA_MODIFIABLE_TMA_SM90A_ENABLED|' \
  -i "include/cutlass/arch/config.h"
# Disable TMA, because we haven't implemented it yet.
sed -Ee 's|# *define *CUTE_COPY_ATOM_TMA_SM90_ENABLED|//CUTE_COPY_ATOM_TMA_SM90_ENABLED|' \
  -i "include/cute/atom/copy_atom.hpp"
sed -Ee 's|#define CUDA_12_0_SM90_FEATURES_SUPPORTED true|//#define CUDA_12_0_SM90_FEATURES_SUPPORTED true|' \
  -i "test/unit/common/cutlass_unit_test.h"
# Disable fp8, because we haven't implemented it yet.
sed -Ee 's|#define CUDA_FP8_ENABLED|//CUDA_FP8_ENABLED|' \
  -i "include/cutlass/float8.h"
# Skip the sm90 example, since it uses tensormaps too.
sed -Ee 's|wgmma_sm90.cu|sgemm_sm80.cu|' \
  -i "examples/cute/tutorial/CMakeLists.txt"
# Disable SM-number checking to skip tests, so all tests always run.
sed -Ee 's|supported = false;|supported = true;|' \
  -i "examples/13_two_tensor_op_fusion/test_run.h"

echo "Done wih CUTLASS"

# 3) Patch flash attention
echo "Patch flash attention"
cd ../flash-attention
git stash
git apply "${SCRIPT_DIR}/patches/flash_attention_typename_patch.diff"

echo "Done patching"
