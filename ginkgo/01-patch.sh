#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh

if [[ -n "${SCALE_ENV:-}" && "${TEST_GPU_ARCH}" == gfx* ]]; then
    # The sync-free triangular solve Ginkgo uses on cc >= 7 spins on other lanes of its own warp,
    # which needs independent thread scheduling. AMD GPUs don't have that, so use Ginkgo's pre-Volta
    # kernel.
    F=ginkgo/cuda/solver/common_trs_kernels.cuh
    grep -q 'is_fallback_required = exec->get_major_version() < 7;' "${F}"
    sed -i 's/is_fallback_required = exec->get_major_version() < 7;/is_fallback_required = true;/' \
        "${F}"

    # This test's matrix is badly conditioned (|x| ~ 1e13), and it compares two rounding errors
    # against 1e-14: NVIDIA's cuSPARSE scores 9.1e-15, rocSPARSE 1.07e-14. Against the exact
    # solution, both have the same error distribution over many such matrices.
    F=ginkgo/cuda/test/solver/upper_trs_kernels.cu
    sed -i '/^TEST_F(UpperTrs, CudaSingleRhsApplyIsEquivalentToRef)$/,/^}$/s/1e-14/1e-13/' "${F}"
    grep -A12 '^TEST_F(UpperTrs, CudaSingleRhsApplyIsEquivalentToRef)$' "${F}" | grep -q 1e-13
fi
