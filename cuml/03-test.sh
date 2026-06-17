#!/bin/bash

set -ETeuo pipefail

SCRIPT_DIR="$(realpath "$(dirname "$0")")"
BUILD_DIR="$(realpath cuml/cpp/build)"

# Runtime validation: link a tiny client against the freshly built libcuml.so and
# run an actual algorithm (L-BFGS linear regression via ML::GLM::qnFit) on the GPU.
#
# Include dirs mirror the dependencies rapids-cmake/CPM fetched into the build tree
# so the header-only raft/rmm/cccl code compiles against the same versions the
# library was built with.
INCS=(-I cuml/cpp/include)
for d in cuml/cpp/build/_deps/*-src ; do
    for inc in "$d/include" "$d/cpp/include" ; do
        [ -d "$inc" ] && INCS+=(-I "$inc")
    done
done
for inc in cuml/cpp/build/_deps/cccl-src/libcudacxx/include \
           cuml/cpp/build/_deps/cccl-src/cub \
           cuml/cpp/build/_deps/cccl-src/thrust ; do
    [ -d "$inc" ] && INCS+=(-I "$inc")
done

# Same SCALE compatibility flags / cusolver shim as the build.
nvcc -std=c++17 -O2 \
    -Xcompiler=-Wno-error -DCCCL_DISABLE_WARPSPEED_SCAN \
    -include "${SCRIPT_DIR}/scale_cusolver_shim.h" \
    "${INCS[@]}" \
    "${SCRIPT_DIR}/cuml_qn_test.cu" \
    -L "${BUILD_DIR}" -lcuml \
    -o cuml_qn_test

# Expected to FAIL on SCALE 1.7.1: CUB/thrust device reductions misbehave on
# gfx90a (DeviceReduce::Sum returns 0; thrust::reduce throws
# cudaErrorInvalidDeviceFunction), so qnFit hangs in its first iteration. The
# timeout turns that hang into a clean failure; if SCALE's reductions get fixed,
# the program returns 0.
LD_LIBRARY_PATH="${BUILD_DIR}:${LD_LIBRARY_PATH:-}" timeout 300 ./cuml_qn_test
