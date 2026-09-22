#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh
raise_error_if_using_rocm

SM_NUM="${CUDAARCHS}"

# This project is pretty ancient and has its own rather loopy way to get flags into the
# nvcc call. CMake list syntax is required in CUDA_NVCC_FLAGS_RELEASE.
args=(
    -DCMAKE_POLICY_VERSION_MINIMUM=3.5
    -DCMAKE_BUILD_TYPE=Release
    -DCMAKE_CUDA_ARCHITECTURES="${SM_NUM}"

    # Work around some overly strict compiler/cuda toolkit detection
    "-DCMAKE_C_COMPILER=$(which clang)"
    "-DCMAKE_CXX_COMPILER=$(which clang++)"
    -DCUDA_TOOLKIT_ROOT_DIR="${CUDA_PATH}"
    "-DCUDA_NVCC_EXECUTABLE=$(which nvcc)"

    -DCMAKE_C_FLAGS="-Wno-error=implicit-function-declaration -Wno-error=implicit-int -Wno-deprecated-declarations"
    -DCMAKE_CXX_FLAGS="-Wno-unused-result -Wno-stringop-overread -Wno-switch -Wno-deprecated-declaration"
    -DCUDA_NVCC_FLAGS_RELEASE="-gencode;arch=compute_${SM_NUM},code=sm_${SM_NUM};-Wno-unused-result;-Wno-switch;-Wno-error=implicit-const-int-float-conversion;-Wno-deprecated-declarations"
)

cmake \
    "${args[@]}" \
    -B"build" \
    "gpu_jpeg2k"

cmake --build "build" -j"$(nproc)"
