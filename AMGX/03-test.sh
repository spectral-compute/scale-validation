#!/bin/bash

set -e
source "$(dirname "$0")"/../util/args.sh "$@"
cd "${OUT_DIR}/AMGX/AMGX/build"

export LD_LIBRARY_PATH="${CUDA_PATH}/lib"
ls "${LD_LIBRARY_PATH}"

# Just running ./src/amgx_tests_launcher generates a lot of failures even on Nvidia. So only run the tests that pass
# there.
EXCLUSIONS=(
    # Tests that fail on Nvidia.
    BlockConversionTest CAPIUploadCudaHostRegister CAPIUploadCudaMalloc CAPIUploadCudaMallocHost
    CAPIUploadCudaMallocManaged CAPIUploadNew DiagonalMatrix EigenSolverTest_InverseIteration
    EigenSolverTest_PowerIteration EnergyminAlgorithmTest ExplicitZeroValues GeneratedMatrixDistributedIOTest
    GeneratedMatrixIOTest ILU1_coloringA ILU1_in_vs_out_diag ILU_DILU_equivalence ImplicitZeroInDiagonal
    ImplicitZeroInDiagonal MatrixColoringTestatmosmodj MatrixColoringTestatmosmodl MatrixColoringTestpoisson
    Memory_Use_DILU Memory_Use_DILU2 Memory_Use_DILU3 Memory_Use_ILU Memory_Use_ILU2 Memory_Use_ILU3
    Memory_Use_atmosmodd_pressure MultiPairwise PreconditionerUsage ProfileTest RowMajorVsColMajor ScalarSmootherPoisson
    SmootherBlocksizes SmootherCusparse SmootherNaNRandom

    # Tests that fail on SCALE. At least one of these is down to UB that I have a patch for on a branch
    # (feat/PatchAmgxUb), and also down to incorrect instruction selection that I have a small-ish reproducer for (needs
    # more work that I got diverted away from).
    # https://gitlab.com/spectral-ai/engineering/cuda/platform/compiler/llvm-project/-/issues/638
    LowDegDeterminism MinMaxColoringTest

    # Tests which don't report failure, but which print errors regarding memory corruption or
    # invalid usage of internal data structures on both SCALE and NV
    CAPIFailure FGMRESConvergencePoisson NestedSolvers
)
EXCLUSIONS_SED=
for TEST in "${EXCLUSIONS[@]}" ; do
    EXCLUSIONS_SED="${EXCLUSIONS_SED};/${TEST}/d"
done
./src/amgx_tests_launcher $(./src/amgx_tests_launcher --help | sed -E "1,/Available tests are:/d;${EXCLUSIONS_SED}")
