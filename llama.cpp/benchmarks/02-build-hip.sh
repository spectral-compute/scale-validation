#!/usr/bin/env bash
# shellcheck source-path=SCRIPTDIR
. "$(dirname "$0")"/../../util/prelude.sh

args=(
    -DCMAKE_BUILD_TYPE=Release
    -DCMAKE_INSTALL_PREFIX="install"
    -DGGML_HIP=ON
    -DGPU_TARGETS="${TEST_GPU_ARCH}"
    -DGGML_NATIVE=OFF
    -DLLAMA_BUILD_UI=OFF
)
HIPCXX="${HIPCXX:-$(hipconfig -l)/clang}" HIP_PATH="$(hipconfig -R)" \
    cmake "${args[@]}" -B"build" "llama.cpp"
make -O -C "build" install -j"$(nproc)"
