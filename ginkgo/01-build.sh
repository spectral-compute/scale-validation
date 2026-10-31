#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh

args=(
    -DCMAKE_BUILD_TYPE=Release
    -DCMAKE_CUDA_COMPILER=nvcc
    -DCMAKE_CUDA_ARCHITECTURES="${CUDAARCHS}"

    -DGINKGO_BUILD_CUDA=ON
    -DGINKGO_BUILD_HIP=OFF
    -DGINKGO_BUILD_SYCL=OFF
    -DGINKGO_BUILD_MPI=OFF
    -DGINKGO_BUILD_TESTS=ON
    -DGINKGO_BUILD_BENCHMARKS=ON
    -DGINKGO_BUILD_EXAMPLES=ON

    # What Ginkgo's own CI uses: smaller inputs for a few slow tests.
    -DGINKGO_FAST_TESTS=ON
    -GNinja
)

cmake "${args[@]}" -B build -S ginkgo

# -k 0: build as much as possible, for more signal on what's unsupported.
ninja -C build -k 0
