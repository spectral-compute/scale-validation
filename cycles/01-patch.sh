#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh

# SCALE's NVIDIA mode uses clang's CUDA headers, which define __float_as_int & co, so
# Cycles' own definitions (guarded only by `ifndef __HIP__`) are redefinitions. NVIDIA's
# nvcc and SCALE on AMD accept them, so only patch for SCALE on sm_* targets.
if [[ -n "${SCALE_ENV:-}" && "${TEST_GPU_ARCH}" == sm_* ]]; then
    patch -p0 -d "cycles" <"${SCRIPT_DIR}/intrinsics.patch"
fi
