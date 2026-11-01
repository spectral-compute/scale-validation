#!/usr/bin/env bash
# shellcheck source-path=SCRIPTDIR
. "$(dirname "$0")"/../../util/prelude.sh
. "$(dirname "$0")"/../chapel.env
PATH="${CHPL_HOME}/bin/$("${CHPL_HOME}"/util/chplenv/chpl_bin_subdir.py):${PATH}"

# ChOp's HIP ports, for comparison: the Chapel search over kernels/AMD_queens_kernels.hip, and
# NQueens/hip, built as NQueens/hip/compiling says.
make -C ChOp CHPL_ROCM_PATH="${ROCM_PATH}" ROCM_GPU_ARCH="${TEST_GPU_ARCH}" queens_singlelocale_amd

cd ChOp/NQueens/hip
hipcc -DHIP_OLD_VERSION -DWARMUP -DIMPROVED -DCHECKSOLS --offload-arch="${TEST_GPU_ARCH}" -O3 \
    singleGPUQueens.hip -o singleGPUQueens
