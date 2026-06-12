#!/bin/bash

set -e

SCRIPT_DIR="$(realpath "$(dirname "$0")")"

# Add the __syncwarp() the CUDA model requires in the f32 tensor-core matmul kernels (mul_mat_f /
# mul_mat_f_ids) and the MoE id-compaction helper (mm_ids_helper), which exchange data across warp
# lanes through shared memory (warp-lockstep execution is not guaranteed).
git -C llama.cpp apply "${SCRIPT_DIR}/mmf-warp-sync.patch"

# Decode the MXFP4 (E8M0) and NVFP4 (UE4M3) block scales via the portable software path, so the
# dequantized values are bit-identical to the CPU reference on every target.
git -C llama.cpp apply "${SCRIPT_DIR}/fp4-scale-decode.patch"

# Flash attention: when an MMA config needs more shared memory than the device provides, fall back
# to the shared-memory-frugal tile kernel. The check is device-adaptive (actual requirement vs the
# device's actual limit), so it adapts to targets with differing shared-memory sizes.
git -C llama.cpp apply "${SCRIPT_DIR}/fattn-shared-mem-fallback.patch"

# Use the single-block soft-max reduction (the only consumer of cooperative launch) by reporting
# cooperative launch as unsupported.
git -C llama.cpp apply "${SCRIPT_DIR}/disable-cooperative-launch.patch"

# Widen two test-backend-ops NMSE bounds for known fp-rounding differences.
git -C llama.cpp apply "${SCRIPT_DIR}/relax-nmse-bounds.patch"
