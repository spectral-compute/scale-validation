#!/bin/bash


set -ETeuo pipefail
SCRIPT_DIR="$(realpath "$(dirname "$0")")"
source "${SCRIPT_DIR}"/../util/args.sh "$@"

SRCDIR="${OUT_DIR}/cutlass/cutlass"

# Always disable clustering.
sed -Ee 's|#  define CUTLASS_SM90_CLUSTER_LAUNCH_ENABLED|//CUTLASS_SM90_CLUSTER_LAUNCH_ENABLED|' -i ${SRCDIR}/include/cutlass/cluster_launch.hpp

# Disable sparse mma, because we haven't implemented it yet.
sed -Ee 's|#define CUTLASS_ARCH_SPARSE_MMA_SM80_ENABLED|//CUTLASS_ARCH_SPARSE_MMA_SM80_ENABLED|' -i ${SRCDIR}/include/cutlass/arch/mma_sparse_sm80.h

# Disable tensormaps, because we haven't implemented them yet.
sed -Ee 's|#define CUDA_HOST_ADAPTER_TENSORMAP_ENABLED|//CUDA_HOST_ADAPTER_TENSORMAP_ENABLED|' -i ${SRCDIR}/include/cutlass/cuda_host_adapter.hpp

# Disable TMA, because we haven't implemented it yet.
sed -Ee 's|# *define *CUTE_COPY_ATOM_TMA_SM90_ENABLED|//CUTE_COPY_ATOM_TMA_SM90_ENABLED|' -i ${SRCDIR}/include/cute/atom/copy_atom.hpp

# Disable fp8, because we haven't implemented it yet.
sed -Ee 's|#define CUDA_FP8_ENABLED|//CUDA_FP8_ENABLED|' -i ${SRCDIR}/include/cutlass/float8.h

# Disable SM-number checking to skip tests, so all tests always run.
sed -Ee 's|supported = false;|supported = true;|' -i ${SRCDIR}/examples/13_two_tensor_op_fusion/test_run.h
