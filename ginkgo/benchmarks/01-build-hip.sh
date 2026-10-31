#!/usr/bin/env bash
# shellcheck source-path=SCRIPTDIR
. "$(dirname "$0")"/../../util/prelude.sh

# Ginkgo's native HIP backend, for comparison. Only the benchmarks are built (they need the OpenMP
# module for their host executor).
args=(
    -DCMAKE_BUILD_TYPE=Release
    -DCMAKE_C_COMPILER="${ROCM_PATH}/llvm/bin/clang"
    -DCMAKE_CXX_COMPILER="${ROCM_PATH}/llvm/bin/clang++"
    -DCMAKE_HIP_ARCHITECTURES="${TEST_GPU_ARCH}"

    -DGINKGO_BUILD_HIP=ON
    -DGINKGO_BUILD_CUDA=OFF
    -DGINKGO_BUILD_SYCL=OFF
    -DGINKGO_BUILD_OMP=ON
    -DGINKGO_BUILD_MPI=OFF
    -DGINKGO_BUILD_TESTS=OFF
    -DGINKGO_BUILD_EXAMPLES=OFF
    -DGINKGO_BUILD_BENCHMARKS=ON
    -GNinja
)

# Ginkgo only disables its custom thrust namespace for HIP 7.1, but rocThrust in ROCm 7.2 is broken
# by it too (unqualified ::thrust in rocThrust's own headers).
sed -i 's/AND GINKGO_HIP_VERSION VERSION_LESS 7.2$/AND GINKGO_HIP_VERSION VERSION_LESS 7.3/' ginkgo/CMakeLists.txt

cmake "${args[@]}" -B build -S ginkgo

ninja -C build
