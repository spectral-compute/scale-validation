#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh

# The sync-free triangular solve Ginkgo uses on cc >= 7 spins on other lanes of its own warp, which
# needs independent thread scheduling. AMD GPUs don't have that, so use Ginkgo's pre-Volta kernel.
if [[ -n "${SCALE_ENV:-}" && "${TEST_GPU_ARCH}" == gfx* ]]; then
    F=ginkgo/cuda/solver/common_trs_kernels.cuh
    grep -q 'is_fallback_required = exec->get_major_version() < 7;' "${F}"
    sed -i 's/is_fallback_required = exec->get_major_version() < 7;/is_fallback_required = true;/' \
        "${F}"
fi
