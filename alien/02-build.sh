#!/bin/bash

set -ETeuo pipefail

export VCPKG_KEEP_ENV_VARS=CMAKE_POLICY_VERSION_MINIMUM
export CMAKE_POLICY_VERSION_MINIMUM=3.5

# vcpkg's own bootstrap only reports "see build/vcpkg-bootstrap.log" on failure and
# that log is otherwise lost with the rest of the failed build's container filesystem
# -- print it so a failing CI run actually shows the real reason.
trap 'test -f build/vcpkg-bootstrap.log && cat build/vcpkg-bootstrap.log' ERR

# Configure.
cmake \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_CXX_FLAGS="-Wno-stringop-overread -Wno-format-truncation -Wno-format -Wno-switch" \
    -DCMAKE_CUDA_FLAGS="-Wno-format -Wno-switch" \
    -DCMAKE_CUDA_ARCHITECTURES="${CUDAARCHS}" \
    -DCMAKE_CUDA_COMPILER="nvcc" \
    -B"build" \
    "alien"

# Build.
make -O -C "build" -j"$(nproc)"
