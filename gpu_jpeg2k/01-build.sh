#!/bin/bash

set -ETeuo pipefail
SCRIPT_DIR="$(realpath "$(dirname "$0")")"
source "${SCRIPT_DIR}"/../util/args.sh "$@"

SM_NUM=$(echo "${GPU_ARCH}" | sed -E 's/sm_//g')

# This project is pretty ancient and has its own rather loopy way to get flags into the
# nvcc call. CMake list syntax is required in CUDA_NVCC_FLAGS_RELEASE.
cmake \
    -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_CUDA_ARCHITECTURES="${SM_NUM}" \
    -DCMAKE_C_FLAGS="-Wno-error=implicit-function-declaration -Wno-error=implicit-int -Wno-deprecated-declarations" \
    -DCMAKE_CXX_FLAGS="-Wno-unused-result -Wno-stringop-overread -Wno-switch -Wno-deprecated-declaration" \
    -DCUDA_NVCC_FLAGS_RELEASE="-gencode;arch=compute_${SM_NUM},code=sm_${SM_NUM};-Wno-unused-result;-Wno-switch;-Wno-error=implicit-const-int-float-conversion;-Wno-deprecated-declarations" \
    -B"${OUT_DIR}/gpu_jpeg2k/build" \
    "${OUT_DIR}/gpu_jpeg2k/gpu_jpeg2k"

# Make sure we actually found CUDA.
"${SCRIPT_DIR}"/../util/check-cmake-cuda-version.sh "${OUT_DIR}/gpu_jpeg2k/build"

# Build.
cmake --build "${OUT_DIR}/gpu_jpeg2k/build" -j"$(nproc)"
