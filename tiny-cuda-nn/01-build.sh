#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh

export SCALE_CUDA_VERSION="11.4"

# Configure.
cmake \
    -DCMAKE_BUILD_TYPE=RelWithDebInfo \
    -B"build" \
    "tiny-cuda-nn"

# Build.
cmake --build build -j"$(nproc)"
