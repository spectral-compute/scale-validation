#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh

# Just running ./src/amgx_tests_launcher generates a lot of failures even on Nvidia. So only run the tests that pass
# there.
EXCLUSIONS=(
    # Tests that fail on Nvidia.
    BlockConversionTest CAPIUploadCudaHostRegister CAPIUploadCudaMalloc CAPIUploadCudaMallocHost
    CAPIUploadCudaMallocManaged CAPIUploadNew EigenSolverTest_InverseIteration
    EigenSolverTest_PowerIteration EnergyminAlgorithmTest ExplicitZeroValues GeneratedMatrixDistributedIOTest
    GeneratedMatrixIOTest ILU1_coloringA ILU1_in_vs_out_diag ILU_DILU_equivalence ImplicitZeroInDiagonal
    MatrixColoringTestatmosmodj MatrixColoringTestatmosmodl MatrixColoringTestpoisson
    Memory_Use_DILU Memory_Use_DILU2 Memory_Use_DILU3 Memory_Use_ILU Memory_Use_ILU2 Memory_Use_ILU3
    Memory_Use_atmosmodd_pressure MultiPairwise PreconditionerUsage ProfileTest RowMajorVsColMajor ScalarSmootherPoisson
    SmootherBlocksizes SmootherCusparse SmootherNaNRandom

    # Tests which don't report failure, but which print errors regarding memory corruption or
    # invalid usage of internal data structures on both SCALE and NV
    CAPIFailure NestedSolvers
)
EXCLUSIONS_SED=
for TEST in "${EXCLUSIONS[@]}"; do
    EXCLUSIONS_SED="${EXCLUSIONS_SED};/${TEST}/d"
done

cd build
mapfile -t TESTS < <(./src/amgx_tests_launcher --help | sed -E "1,/Available tests are:/d;${EXCLUSIONS_SED}")
./src/amgx_tests_launcher "${TESTS[@]}" | tee amgx_tests.log

# The launcher exits 0 even when tests fail.
grep -Eq "Total tests run: [1-9][0-9]*\s+Failed tests: 0$" amgx_tests.log
