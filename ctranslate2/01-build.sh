#!/usr/bin/env bash
. "$(dirname "$0")"/../util/prelude.sh

args=(
    -DCMAKE_BUILD_TYPE=Release
    -DCUDA_TOOLKIT_ROOT_DIR="${CUDA_PATH}"
    -DCMAKE_CUDA_COMPILER="nvcc"
    -DCMAKE_CUDA_ARCHITECTURES="${CUDAARCHS}"
    -DCUDA_ARCH_LIST="8.6"
    -DCUDA_NVCC_FLAGS="-Wno-pass-failed -Wno-deprecated-builtins -Wno-unused-result -Wno-missing-braces -Wno-unused-parameter -Wno-sign-compare -Wno-unused-local-typedef"

    -DWITH_CUDA=ON
    -DWITH_MKL=OFF
    -DOPENMP_RUNTIME=COMP

    -DBUILD_TESTS=ON
)

cmake \
    "${args[@]}" \
    -B"build" \
    "ctranslate2"

make -O -C "build" -j"$(nproc)"
