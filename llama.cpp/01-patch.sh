#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh

# Flash attention: when an MMA config needs more shared memory than the device provides, fall back
# to the shared-memory-frugal tile kernel. The check is device-adaptive (actual requirement vs the
# device's actual limit), so it adapts to targets with differing shared-memory sizes.
git -C llama.cpp apply "${SCRIPT_DIR}/fattn-shared-mem-fallback.patch"

# Use the single-block soft-max reduction (the only consumer of cooperative launch) by reporting
# cooperative launch as unsupported.
git -C llama.cpp apply "${SCRIPT_DIR}/disable-cooperative-launch.patch"

# Build without NVIDIA's device-level CUB algorithms (cub::DeviceReduce, cub::DeviceRadixSort,
# cub::DeviceScan, cub::DeviceTopK); the affected ops use llama.cpp's native kernels (bitonic
# argsort, sum-rows reduction, native scan), as upstream does for non-NVIDIA backends.
git -C llama.cpp apply "${SCRIPT_DIR}/disable-cub.patch"
