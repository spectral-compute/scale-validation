#!/bin/bash

set -e

SCRIPT_DIR="$(realpath "$(dirname "$0")")"

# Flash attention: when an MMA config needs more shared memory than the device provides, fall back
# to the shared-memory-frugal tile kernel. The check is device-adaptive (actual requirement vs the
# device's actual limit), so it adapts to targets with differing shared-memory sizes.
git -C llama.cpp apply "${SCRIPT_DIR}/fattn-shared-mem-fallback.patch"

# Flash attention: take the barrier in the stream-k combine step out of control flow that differs
# between warps. Where two warps share a wider wave and take different branches, that wave reaches
# the barrier twice and a wave whose warps agree reaches it once, leaving the block out of step.
git -C llama.cpp apply "${SCRIPT_DIR}/fattn-divergent-barrier.patch"

# Use the single-block soft-max reduction (the only consumer of cooperative launch) by reporting
# cooperative launch as unsupported.
git -C llama.cpp apply "${SCRIPT_DIR}/disable-cooperative-launch.patch"

# Build without NVIDIA's device-level CUB algorithms (cub::DeviceReduce, cub::DeviceRadixSort,
# cub::DeviceScan, cub::DeviceTopK); the affected ops use llama.cpp's native kernels (bitonic
# argsort, sum-rows reduction, native scan), as upstream does for non-NVIDIA backends.
git -C llama.cpp apply "${SCRIPT_DIR}/disable-cub.patch"
