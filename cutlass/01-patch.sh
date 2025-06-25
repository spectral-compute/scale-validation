#!/bin/bash


set -ETeuo pipefail
SCRIPT_DIR="$(realpath "$(dirname "$0")")"
source "${SCRIPT_DIR}"/../util/args.sh "$@"

SRCDIR="${OUT_DIR}/cutlass/cutlass"

# Always disable clustering.
sed -Ee 's|#  define CUTLASS_SM90_CLUSTER_LAUNCH_ENABLED|//CUTLASS_SM90_CLUSTER_LAUNCH_ENABLED|' -i ${SRCDIR}/include/cutlass/cluster_launch.hpp

# Disable sparse mma, because we haven't implemented it yet.
sed -Ee 's|#define CUTLASS_ARCH_SPARSE_MMA_SM80_ENABLED|//CUTLASS_ARCH_SPARSE_MMA_SM80_ENABLED|' -i ${SRCDIR}/include/cutlass/arch/mma_sparse_sm80.h

# Disable fp8, because we haven't implemented it yet.
sed -Ee 's|#define CUDA_FP8_ENABLED|//CUDA_FP8_ENABLED|' -i ${SRCDIR}/include/cutlass/float8.h

# Disable the 1-bit MMAs, because we haven't implemented them yet.
sed -Ee 's|#define CUTLASS_ARCH_MMA_B1_AND_SM80_ENABLED|//CUTLASS_ARCH_MMA_B1_AND_SM80_ENABLED|' -i ${SRCDIR}/include/cutlass/arch/mma_sm80.h
sed -Ee 's|#define CUTLASS_ARCH_MMA_B1_XOR_SM80_ENABLED|//CUTLASS_ARCH_MMA_B1_XOR_SM80_ENABLED|' -i ${SRCDIR}/include/cutlass/arch/mma_sm80.h

## Disable sub-byte integer matmuls.
#sed -Ee 's|#define CUTLASS_SUBBYTE_INTEGER_MATRIX_MULTIPLY_ENABLED|//CUTLASS_SUBBYTE_INTEGER_MATRIX_MULTIPLY_ENABLED|' -i ${SRCDIR}/include/cutlass/arch/wmma.h
#
## Disable all use of sm75 WMMA, because we don't have bmma yet.
## https://gitlab.com/spectral-ai/engineering/cuda/platform/redscale/-/issues/580
#sed -Ee 's|#define CUTLASS_ARCH_WMMA_SM75_ENABLED|//CUTLASS_ARCH_WMMA_SM75_ENABLED|' -i ${SRCDIR}/include/cutlass/arch/wmma.h

# Disable SM-number checking to skip tests, so all tests always run.
sed -Ee 's|supported = false;|supported = true;|' -i ${SRCDIR}/examples/13_two_tensor_op_fusion/test_run.h
